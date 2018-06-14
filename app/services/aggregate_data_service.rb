# This should take a meter collection and populate
# it with aggregated & validated data
class AggregateDataService
  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @heat_meters        = @meter_collection.heat_meters
    @electricity_meters = @meter_collection.electricity_meters
  end

  def validate_and_aggregate_meter_data
    validate_meter_data
    aggregate_heat_meters
    create_storage_heater_meters # create before electric aggregation
    aggregate_electricity_meters
    create_solar_pv_meters

    # Return populated with aggregated data
    @meter_collection
  end

private

  def validate_meter_data
    validate_meter_list(@heat_meters)
    validate_meter_list(@electricity_meters)
  end

  def validate_meter_list(list_of_meters)
    puts "Validating #{list_of_meters.length} meters"
    list_of_meters.each do |meter|
      validate_meter = ValidateAMRData.new(meter, 30, @meter_collection.holidays, @meter_collection.temperatures)
      validate_meter.validate
    end
  end

  # if the electricity meter has a storage heater, split the meter
  # into 2 one with storage heater only kwh, the other with the remainder
  def create_storage_heater_meters
    @electricity_meters.each do |electricity_meter|
      next if electricity_meter.storage_heaters.nil?

      puts 'Disaggregating electricity meter into 1x storage heater only and 1 x remainder'

      electric_only_amr, storage_heater_amr = electricity_meter.storage_heaters.disaggregate_amr_data(electricity_meter.amr_data)
    
      electric_only_meter = create_modified_meter_copy(
        electricity_meter,
        electric_only_amr,
        :electricity,
        electricity_meter.id + ' minus storage heater',
        electricity_meter.name + ' minus storage heater'
      )

      storage_heater_meter = create_modified_meter_copy(
        electricity_meter,
        storage_heater_amr,
        :storage_heater,
        electricity_meter.id + ' storage heater only',
        electricity_meter.name + ' storage heater only'
      )

      # find and replace existing electric meter with one without storage heater
      for i in 0..@electricity_meters.length - 1 do
        if @electricity_meters[i].id == electricity_meter.id
          @electricity_meters[i] = electric_only_meter
          break
        end
      end
      @meter_collection.storage_heater_meters.push(storage_heater_meter)
    end
  end

  # creates artificial PV meters, if solar pv present by scaling
  # 1/2 hour yield data from Sheffield University by the kWp(s) of
  # the PV installation; note the kWh is negative as its a producer
  # rather than a consumer
  def create_solar_pv_meters
    @electricity_meters.each do |electricity_meter|
      next if electricity_meter.solar_pv_installation.nil?

      puts 'Creating an artificial solar pv meter and associated amr data'

      solar_amr = create_solar_pv_amr_data(
                    electricity_meter.amr_data,
                    electricity_meter.solar_pv_installation
                  )

      solar_pv_meter = create_modified_meter_copy(
        electricity_meter,
        solar_amr,
        :solar_pv,
        'solarpvid',
        electricity_meter.solar_pv_installation.to_s
      )
      @meter_collection.solar_pv_meters.push(solar_pv_meter)
    end
  end

  def create_modified_meter_copy(meter, amr_data, type, identifier, name)
    Meter.new(
      meter_collection,
      amr_data, 
      type, 
      identifier,
      name,
      meter.floor_area,
      meter.number_of_pupils,
      meter.solar_pv_installation,
      meter.storage_heaters
    )
  end

  def create_solar_pv_amr_data(electricity_amr, solar_pv_installation)
    solar_amr = AMRData.new(:solar_pv)
    (electricity_amr.start_date..electricity_amr.end_date).each do |date|
      if date >= meter_collection.solar_pv.start_date
        scale_factor = solar_pv_installation.capacity_kwp_on_date(date)
        days_pv_yield = meter_collection.solar_pv[date]
        producer = -1.0 # negate kWh as producer rather than consumer
        scaled_pv_kwh = days_pv_yield.map { |i| i * scale_factor * producer }
        solar_amr.add(date, scaled_pv_kwh)
      end
    end
    puts "Created new solar pv meter with #{solar_amr.length} days of data"
    solar_amr
  end

  def aggregate_heat_meters
    @meter_collection.aggregated_heat_meters = aggregate_meters(@heat_meters, :gas)
  end

  def aggregate_electricity_meters
    @meter_collection.aggregated_electricity_meters = aggregate_meters(@electricity_meters, :electricity)
  end

  def heating_model(period)
    unless @heating_models.key?(:basic)
      @heating_models[:basic] = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(@aggregated_heat_meters.amr_data, @meter_collection.holidays, @meter_collection.temperatures)
      @heating_models[:basic].calculate_regression_model(period)
    end
    @heating_models[:basic]
    #  @heating_on_periods = @model.calculate_heating_periods(@period)
  end

  def aggregate_meters(list_of_meters, type)
    if list_of_meters.length == 1
      return list_of_meters[0] # optimisaton if only 1 meter, then its its own aggregate
    end
    min_date = first_combined_meter_reading_date(list_of_meters)
    max_date = last_combined_meter_reading_date(list_of_meters)
    puts "Aggregating data between #{min_date} #{max_date}"

    combined_amr_data = AMRData.new(type)
    (min_date..max_date).each do |date|
      combined_data = Array.new(48, 0.0)
      list_of_meters.each do |meter|
        (0..47).each do |half_hour_index|
          if meter.amr_data.key?(date)
            combined_data[half_hour_index] += meter.amr_data[date][half_hour_index]
          end
        end
      end
      combined_amr_data.add(date, combined_data)
    end

    meter_names = []
    ids = []
    floor_area = 0
    pupils = 0
    list_of_meters.each do |meter|
      meter_names.push(meter.name)
      ids.push(meter.id)
      if !floor_area.nil? && !meter.floor_area.nil?
        floor_area += meter.floor_area
      else
        floor_area = nil
      end
      if !pupils.nil? && !meter.number_of_pupils.nil?
        pupils += meter.number_of_pupils
      else
        pupils = nil
      end
    end
    name = meter_names.join(' + ')
    id = ids.join(' + ')
    combined_meter = Meter.new(self, combined_amr_data, type, id, name, floor_area, pupils)

    puts "Creating combined meter data #{combined_amr_data.start_date} to #{combined_amr_data.end_date}"
    puts "with floor area #{floor_area} and #{pupils}"
    combined_meter
  end

  # find minimum data where all listed meters have a meter reading
  def first_combined_meter_reading_date(list_of_meters)
    min_date = Date.new(1900, 1, 1)
    list_of_meters.each do |meter|
      if meter.amr_data.start_date > min_date
        min_date = meter.amr_data.start_date
      end
    end
    min_date
  end

  def last_combined_meter_reading_date(list_of_meters)
    max_date = Date.new(2100, 1, 1)
    list_of_meters.each do |meter|
      if meter.amr_data.end_date < max_date
        max_date = meter.amr_data.end_date
      end
    end
    max_date
  end
end
