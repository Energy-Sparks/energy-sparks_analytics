
# Temporary name!
# This should take a wrapped up school object and populate
# it with aggregated data

class SuperAggregateDataService
  attr_reader :school_with_aggregated_data

  def initialize(school_with_aggregated_data)
    @school_with_aggregated_data = school_with_aggregated_data
    @heat_meters = @school_with_aggregated_data.heat_meters
    @electricity_meters = @school_with_aggregated_data.electricity_meters
  end

  def validate_and_aggregate_meter_data
    validate_meter_data
    aggregate_heat_meters
    aggregate_electricity_meters

    # Return populated with aggregated data
    @school_with_aggregated_data
  end

private

  def validate_meter_data
    validate_meter_list(@heat_meters)
    validate_meter_list(@electricity_meters)
  end

  def validate_meter_list(list_of_meters)
    puts "Validating #{list_of_meters.length} meters"
    list_of_meters.each do |meter|
      validate_meter = ValidateAMRData.new(meter, 30, @school_with_aggregated_data.holidays, @school_with_aggregated_data.temperatures)
  #    binding.pry
      validate_meter.validate
    end
  end

  def aggregate_heat_meters
    @school_with_aggregated_data.aggregated_heat_meters = aggregate_meters(@heat_meters, :gas)
  end

  def aggregate_electricity_meters
    @school_with_aggregated_data.aggregated_electricity_meters = aggregate_meters(@electricity_meters, :electricity)
  end

  def heating_model(period)
    unless @heating_models.key?(:basic)
      @heating_models[:basic] = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(@aggregated_heat_meters.amr_data, @school_with_aggregated_data.holidays, @school_with_aggregated_data.temperatures)
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
