# not a real 'user' alert, but something which provides basic data to support the
# prioritisation of other alerts
class AlertAdditionalPrioritisationData < AlertAnalysisBase
  include Logging
  attr_reader :days_to_next_holiday, :days_from_last_holiday
  attr_reader :average_temperature_last_week, :average_forecast_temperature_next_week_deprecated
  attr_reader :annual_electricity_kwh, :annual_gas_kwh, :annual_storage_heater_kwh
  attr_reader :annual_electricity_£, :annual_gas_£, :annual_storage_heater_£
  attr_reader :degree_days_15_5C_domestic
  attr_reader :school_area, :school_type_name

  def initialize(school)
    super(school, :prioritisationdata)
    @relevance = :relevant # override gas only AlertGasModelBase values, so works for electricity as well
  end

  def relevance
    :relevant
  end

  def enough_data
    :enough
  end

  def self.template_variables
    specific = {'Prioritisation data' => TEMPLATE_VARIABLES}
  end

  TEMPLATE_VARIABLES = {
    pupils: {
      description: 'Number of pupils for relevant part of school on this date',
      units:  Integer,
      benchmark_code: 'pupn'
    },
    floor_area: {
      description: 'Floor area of relevant part of school',
      units:  :m2,
      benchmark_code: 'flra'
    },
    school_type: {
      description: 'Primary or Secondary',
      units:  :school_type,
      benchmark_code: 'sctp'
    },
    school_type_name: {
      description: 'Primary or Secondary',
      units:  String,
      benchmark_code: 'stpn'
    },
    school_name: {
      description: 'Name of school',
      units: String,
      benchmark_code: 'name'
    },
    school_area: {
      description: 'School area',
      units: String,
      benchmark_code: 'area'
    },
    urn: {
      description: 'School URN',
      units:  Integer,
      benchmark_code: 'urn'
    },
    days_to_next_holiday: {
      description: 'days to next holiday',
      units: Integer,
      priority_code:  'DYTH'
    },
    days_from_last_holiday: {
      description: 'days from_last holiday',
      units: Integer,
      priority_code:  'DYFH'
    },
    average_temperature_last_week: {
      description: 'average_temperature last week',
      units: Float,
      priority_code:  'AVGT'
    },
    average_forecast_temperature_next_week_deprecated: {
      description: 'average forecast temperature next week',
      units: Float,
      priority_code:  'FAVT'
    },
    annual_electricity_kwh: {
      description: 'annual electricity consumption (kWh)',
      units: { kwh: :electricity },
      priority_code:  'EKWH'
    },
    annual_gas_kwh: {
      description: 'annual gas consumption (kWh)',
      units: { kwh: :gas },
      priority_code:  'GKWH'
    },
    annual_storage_heater_kwh: {
      description: 'annual storage heater consumption (kWh)',
      units: { kwh: :gas },
      priority_code:  'SKWH'
    },
    annual_electricity_£: {
      description: 'annual electricity consumption (£)',
      units: { kwh: :electricity },
      priority_code:  'ECST'
    },
    annual_gas_£: {
      description: 'annual gas consumption (£)',
      units: { kwh: :gas },
      priority_code:  'GCST'
    },
    annual_storage_heater_£: {
      description: 'annual storage heater consumption (£)',
      units: { kwh: :gas },
      priority_code:  'SCST'
    },
    degree_days_15_5C_domestic: {
      description: 'Degree days (15.5C base, domestic(i.e. continuous occupation)',
      units: Float,
      benchmark_code: 'ddays'
    }
  }

  # dummy to keep ContentBase constructor happy
  def aggregate_meter
    meters = [@school.aggregated_electricity_meters, @school.aggregated_heat_meters]
    meters.compact[0] 
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
  end

  def calculate(asof_date)
    begin
      calculate_private(asof_date)
    rescue StandardError => e
      logger.info e.message
      0.0
    end
  end

  private def calculate_private(asof_date)
    @days_to_next_holiday = calculate_days_to_next_holiday(asof_date)
    @days_from_last_holiday = calculate_days_to_previous_holiday(asof_date)
    temperatures = AverageHistoricOrForecastTemperatures.new(@school)
    # @average_temperature_last_week = temperatures.calculate_average_temperature_for_week_following(asof_date - 7)
    # @average_forecast_temperature_next_week = temperatures.calculate_average_temperature_for_week_following(asof_date)

    @annual_electricity_kwh     = annual_kwh(@school.aggregated_electricity_meters, :electricity,     asof_date, :kwh)
    @annual_gas_kwh             = annual_kwh(@school.aggregated_heat_meters,        :gas,             asof_date, :kwh)
    @annual_storage_heater_kwh  = annual_kwh(@school.storage_heater_meter,          :storage_heaters, asof_date, :kwh)

    @annual_electricity_£     = annual_kwh(@school.aggregated_electricity_meters, :electricity,     asof_date, :£)
    @annual_gas_£             = annual_kwh(@school.aggregated_heat_meters,        :gas,             asof_date, :£)
    @annual_storage_heater_£  = annual_kwh(@school.storage_heater_meter,          :storage_heaters, asof_date, :£)
    
    @school_type_name = @school.school_type.to_s.humanize

    @degree_days_15_5C_domestic = @school.temperatures.degree_days_this_year(asof_date)

    @school_area = @school.area_name
  end

  private def annual_kwh(meter, fuel_type, asof_date, data_type)
    return 0.0 if meter.nil?
    asof_date = [asof_date, meter.amr_data.end_date].min
    chart_end_date = { asof_date: asof_date }
    begin
      ScalarkWhCO2CostValues.new(@school).aggregate_value({year: 0}, fuel_type, data_type, chart_end_date)
    rescue StandardError => e
      logger.info e.message
      0.0
    end
  end

  private def calculate_days_to_next_holiday(asof_date)
    holiday = @school.holidays.find_next_holiday(asof_date)
    return 0 if asof_date.between?(holiday.start_date, holiday.end_date)
    (holiday.start_date - asof_date).to_i
  end

  private def calculate_days_to_previous_holiday(asof_date)
    holiday = @school.holidays.find_previous_or_current_holiday(asof_date)
    return 0 if asof_date.between?(holiday.start_date, holiday.end_date)
    (asof_date - holiday.end_date).to_i
  end
end
