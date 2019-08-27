# not a real 'user' alert, but something which provides basic data to support the
# prioritisation of other alerts
class AlertAdditionalPrioritisationData < AlertGasModelBase
  attr_reader :heating_on, :days_to_next_holiday, :days_from_last_holiday
  attr_reader :average_temperature_last_week, :average_forecast_temperature_next_week
  attr_reader :annual_electricity_kwh, :annual_gas_kwh, :annual_storage_heater_kwh
  attr_reader :annual_electricity_£, :annual_gas_£, :annual_storage_heater_£

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
    heating_on: {
      description: 'heating on today',
      units: TrueClass,
      priority_code:  'HTON'
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
    average_forecast_temperature_next_week: {
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
    }
  }

  def calculate(asof_date)
    @heating_on = is_heating_on(asof_date)
    @days_to_next_holiday = calculate_days_to_next_holiday(asof_date)
    @days_from_last_holiday = calculate_days_to_previous_holiday(asof_date)
    temperatures = AverageHistoricOrForecastTemperatures.new(@school)
    @average_temperature_last_week = temperatures.calculate_average_temperature_for_week_following(asof_date - 7)
    @average_forecast_temperature_next_week = temperatures.calculate_average_temperature_for_week_following(asof_date)

    @annual_electricity_kwh     = annual_kwh(@school.aggregated_electricity_meters, :electricity,     asof_date, :kwh)
    @annual_gas_kwh             = annual_kwh(@school.aggregated_heat_meters,        :gas,             asof_date, :kwh)
    @annual_storage_heater_kwh  = annual_kwh(@school.storage_heater_meter,          :storage_heaters, asof_date, :kwh)

    @annual_electricity_£     = annual_kwh(@school.aggregated_electricity_meters, :electricity,     asof_date, :£)
    @annual_gas_£             = annual_kwh(@school.aggregated_heat_meters,        :gas,             asof_date, :£)
    @annual_storage_heater_£  = annual_kwh(@school.storage_heater_meter,          :storage_heaters, asof_date, :£)
  end

  private def annual_kwh(aggregate_meter, fuel_type, asof_date, data_type)
    chart_end_date = { asof_date: asof_date }
    aggregate_meter.nil? ? 0.0 : ScalarkWhCO2CostValues.new(@school).aggregate_value({year: 0}, fuel_type, data_type, chart_end_date)
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

  private def is_heating_on(asof_date)
    return false if @school.aggregated_heat_meters.nil?
    return false if @school.aggregated_heat_meters.non_heating_only?
    calculate_model(asof_date)
    heating_model.heating_on?(asof_date)
  end
end
