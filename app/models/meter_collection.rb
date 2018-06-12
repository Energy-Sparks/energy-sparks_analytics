# Was a building!

# building: potentially a misnomer, holds data associated with a group
#           of buildings, which could be a whole school or the area
#           covered by a single meter
#           primarily a placeholder for data associated with a school
#           or group of buildings, potentially different to the parent
#           school, so for example a different holiday and open/close time
#           schedule if a meter covers a community sports centre which is
#           used out of core school hours
#           - also holds modelling data

class MeterCollection
  attr_reader :heat_meters, :electricity_meters

  # From school/building
  attr_reader :floor_area, :number_of_pupils

  # Currently, but not always
  attr_reader :school_type, :school, :name, :address

  # These are things which will be populated
  attr_accessor :aggregated_heat_meters, :aggregated_electricity_meters, :heating_models

  def initialize(school)
    @name = school.name
    @address = school.address
    @floor_area = school.floor_area
    @number_of_pupils = school.number_of_pupils
    @heat_meters = []
    @electricity_meters = []
    @heating_models = {}
    @school = school

    if Object.const_defined?('ScheduleDataManager')
      pp "Running standalone, not in Rails environment"

      # Normally these would come from the school, hard coded at the mo
      @holiday_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @temperature_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @solar_irradiance_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @solar_pv_schedule_name = ScheduleDataManager::BATH_AREA_NAME
    else
      pp "Running in Rails environment"
      throw ArgumentException if school.meters.empty?
    end
  end

  def add_heat_meter(meter)
    @heat_meters.push(meter)
  end

  def add_electricity_meter(meter)
    @electricity_meters.push(meter)
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
    if i_am_running_in_rails?
      ScheduleDataManager.holidays(@holiday_schedule_name, @school.calendar_id)
    else
      ScheduleDataManager.holidays(@holiday_schedule_name)
    end
  end

  def temperatures
    if i_am_running_in_rails?
      temperature_area_id = @school.temperature_area_id || DataFeed.where(type: "DataFeeds::WeatherUnderground").first.area_id

      pp temperature_area_id
      ScheduleDataManager.temperatures(@temperature_schedule_name, temperature_area_id)
    else
      ScheduleDataManager.temperatures(@temperature_schedule_name)
    end

  end

  def solar_insolance
    ScheduleDataManager.solar_irradiation(@solar_irradiance_schedule_name)
  end

  def solar_pv
    ScheduleDataManager.solar_pv(@solar_pv_schedule_name)
  end

  def heating_model(period)
    unless @heating_models.key?(:basic)
      @heating_models[:basic] = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(@aggregated_heat_meters.amr_data, holidays, temperatures)
      @heating_models[:basic].calculate_regression_model(period)
    end
    @heating_models[:basic]
    #  @heating_on_periods = @model.calculate_heating_periods(@period)
  end

private

  def i_am_running_in_rails?
    @school.respond_to?(:calendar)
  end
end
