# Was a building - pulled in to a service for now which can then
# be broken up into maintainable parts


# building: potentially a misnomer, holds data associated with a group
#           of buildings, which could be a whole school or the area
#           covered by a single meter
#           primarily a placeholder for data associated with a school
#           or group of buildings, potentially different to the parent
#           school, so for example a different holiday and open/close time
#           schedule if a meter covers a community sports centre which is
#           used out of core school hours
#           - also holds modelling data

class SuperAggregateDataService

  attr_reader :heat_meters, :electricity_meters
  attr_reader :aggregated_heat_meters, :aggregated_electricity_meters, :heating_models
  attr_reader :name, :address, :floor_area, :number_of_pupils
  attr_reader :school_type

  attr_reader :ar_school

 def initialize(ar_school, name, address, floor_area, number_of_pupils, school_type,
                  holiday_schedule_name = ScheduleDataManager::BATH_AREA_NAME,
                  temperature_schedule_name = ScheduleDataManager::BATH_AREA_NAME,
                  solar_irradiance_schedule_name = ScheduleDataManager::BATH_AREA_NAME,
                  solar_pv_schedule_name = ScheduleDataManager::BATH_AREA_NAME
                  )
    @name = name
    @address = address
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    @heat_meters = []
    @electricity_meters = []
    @heating_models = {}
    @holiday_schedule_name = holiday_schedule_name
    @temperature_schedule_name = temperature_schedule_name
    @solar_irradiance_schedule_name =  solar_irradiance_schedule_name
    @solar_pv_schedule_name = solar_pv_schedule_name
    pp "init"
    pp @holiday_schedule_name
  end

  def validate_and_aggregate_meter_data
    validate_meter_data
    aggregate_heat_meters
    aggregate_electricity_meters
  end

  def add_heat_meter(meter)
    @heat_meters.push(meter)
  end

  def add_electricity_meter(meter)
    @electricity_meters.push(meter)
  end

  private

  def validate_meter_data
    validate_meter_list(@heat_meters)
    validate_meter_list(@electricity_meters)
  end

  def validate_meter_list(list_of_meters)
    puts "Validating #{list_of_meters.length} meters"
    list_of_meters.each do |meter|
      validate_meter = ValidateAMRData.new(meter, 30, holidays, temperatures)
      validate_meter.validate
    end
  end

  # JAMES: TODO(JJ,3Jun2018): I gather you may have done something on this when working on holidays?
  def open_time
    # - use DateTime and not Time as orders of magnitude faster on Windows
    DateTime.new(0, 1, 1, 7, 0, 0) # hard code for moment, but needs to be stored on database, and potentially by day
  end

  def close_time
    # - use DateTime and not Time as orders of magnitude faster on Windows
    DateTime.new(0, 1, 1, 16, 30, 0)
  end

  def school_day_in_hours(time)
    # - use DateTime and not Time as orders of magnitude faster on Windows
    time_only = DateTime.new(0, 1, 1, time.hour, time.min, time.sec)
    time_only >= open_time && time_only < close_time
  end

  # held at building level as a school building e.g. a community swimming pool may have a different holiday schedule
  def holidays
    ScheduleDataManager.holidays(@holiday_schedule_name)
  end

  def temperatures
    ScheduleDataManager.temperatures(@temperature_schedule_name)
  end

  def solar_insolance
    ScheduleDataManager.solar_irradiation(@solar_irradiance_schedule_name)
  end

  def solar_pv
    ScheduleDataManager.solar_pv(@solar_pv_schedule_name)
  end

  def aggregate_heat_meters
    @aggregated_heat_meters = aggregate_meters(@heat_meters, :gas)
  end

  def aggregate_electricity_meters
    @aggregated_electricity_meters = aggregate_meters(@electricity_meters, :electricity)
  end

  def heating_model(period)
    unless @heating_models.key?(:basic)
      @heating_models[:basic] = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(@aggregated_heat_meters.amr_data, holidays, temperatures)
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
