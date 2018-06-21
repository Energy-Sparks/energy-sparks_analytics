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
  attr_reader :heat_meters, :electricity_meters, :solar_pv_meters, :storage_heater_meters

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
    @solar_pv_meters = []
    @storage_heater_meters = []
    @heating_models = {}
    @school = school


    @cached_open_time = DateTime.new(0, 1, 1, 7, 0, 0) # for speed
    @cached_close_time = DateTime.new(0, 1, 1, 16, 30, 0) # for speed

    if i_am_running_in_rails?
      pp "Running in Rails environment"
      @heat_meters = school.heat_meters
      @electricity_meters = school.electricity_meters
      # Stored as big decimal
      @floor_area = school.floor_area.to_f

      @heat_meters.each do |heat_meter|
        heat_meter.amr_data = add_amr_data(heat_meter)
      end

      @electricity_meters.each do |electricity_meter|
        electricity_meter.amr_data = add_amr_data(electricity_meter)
      end
      throw ArgumentException if school.meters.empty?
    else
      # Normally these would come from the school, hard coded at the mo
      @holiday_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @temperature_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @solar_irradiance_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @solar_pv_schedule_name = ScheduleDataManager::BATH_AREA_NAME
      @heat_meters = []
      @electricity_meters = []

      @floor_area = school.floor_area

      pp "Running standalone, not in Rails environment"
    end
  end

  def add_amr_data(meter)
    amr_data = AMRData.new(meter.meter_type)
    readings = []

    query = <<-SQL
      SELECT date_trunc('day', read_at) AS day, array_agg(value ORDER BY read_at ASC) AS values
      FROM meter_readings
      WHERE meter_id = #{meter.id}
      GROUP BY date_trunc('day', read_at)
    SQL

    result = ActiveRecord::Base.connection.exec_query(query)
    result.each do |row|
      amr_data.add(Date.parse(row["day"]), row["values"].delete('{}').split(',').map(&:to_f))
    end
    amr_data
  end

  def add_heat_meter(meter)
    meter.meter_type = meter.meter_type.to_sym if meter.meter_type.instance_of? String
    @heat_meters.push(meter)
  end

  def add_electricity_meter(meter)
     meter.meter_type = meter.meter_type.to_sym if meter.meter_type.instance_of? String
    @electricity_meters.push(meter)
  end

  # JAMES: TODO(JJ,3Jun2018): I gather you may have done something on this when working on holidays?
  def open_time
    @cached_open_time
  end

  def close_time
    @cached_close_time
  end

  def school_day_in_hours(time)
    # - use DateTime and not Time as orders of magnitude faster on Windows
    time_only = DateTime.new(0, 1, 1, time.hour, time.min, time.sec)
    time_only >= open_time && time_only < close_time
  end

  # held at building level as a school building e.g. a community swimming pool may have a different holiday schedule
  def holidays
    if i_am_running_in_rails?
      ScheduleDataManager.holidays(nil, @school.calendar_id)
    else
      ScheduleDataManager.holidays(@holiday_schedule_name)
    end
  end

  def temperatures
    if i_am_running_in_rails?
      temperature_area_id = @school.temperature_area_id || DataFeed.find_by(type: "DataFeeds::WeatherUnderground").area_id
      ScheduleDataManager.temperatures(nil, temperature_area_id)
    else
      ScheduleDataManager.temperatures(@temperature_schedule_name)
    end
  end

  def solar_insolance
    if i_am_running_in_rails?
      solar_irradiance_area_id = @school.solar_irradiance_area_id || DataFeed.find_by(type: "DataFeeds::WeatherUnderground").area_id
      ScheduleDataManager.solar_irradiance(nil, solar_irradiance_area_id)
    else
      ScheduleDataManager.solar_irradiance(@solar_irradiance_schedule_name)
    end
  end

  def solar_pv
    if i_am_running_in_rails?
      solar_pv_tuos_area_id = @school.solar_pv_tuos_area_id || DataFeed.find_by(type: "DataFeeds::SolarPvTuos").area_id
      ScheduleDataManager.solar_pv(nil, solar_pv_tuos_area_id)
    else
      ScheduleDataManager.solar_pv(@solar_pv_schedule_name)
    end
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
