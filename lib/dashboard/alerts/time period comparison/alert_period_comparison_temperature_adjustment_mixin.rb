# shared code between gas/heat derived classes from electricity
# classes to simulate multiple inheritance
module AlertPeriodComparisonTemperatureAdjustmentMixin
  include AlertModelCacheMixin
  attr_reader :total_previous_period_unadjusted_kwh
  attr_reader :total_previous_period_unadjusted_£
  attr_reader :total_previous_period_unadjusted_co2

  def self.unadjusted_template_variables
    {
      total_previous_period_unadjusted_kwh: {
        description: 'Total kwh in previous period, unadjusted for temperature or length of holiday',
        units:  :kwh,
        benchmark_code: 'uapk'
      },
      total_previous_period_unadjusted_£: {
        description: 'Total cost £ in previous period, unadjusted for temperature or length of holiday',
        units:  :£
      },
      total_previous_period_unadjusted_co2:{
        description: 'Total co2 in previous period, unadjusted for temperature or length of holiday',
        units:  :co2
      }
    }
  end

  private def average_previous_period_temperature
    @average_previous_period_temperature ||= calculate_average_previous_period_temperature
  end

  protected def previous_kwh(aggregate_meter, date, data_type)
    @model_calc ||= model_calculation(@model_asof_date) # probably already cached
    kwh = @model_calc.temperature_compensated_one_day_gas_kwh(date, average_previous_period_temperature, target_kwh(date, data_type))
    [kwh, 0.0].max
  end

  private def target_kwh(date, data_type)
    aggregate_meter.amr_data.one_day_kwh(date, data_type, community_use: community_use)
  end

  private def model_calculation(asof_date)
    @model_asof_date = asof_date
    @model = model_cache(@school.urn, asof_date)
  end

  # compensate previous period daily kWh readings to the average
  # temperature in the current period - only applied for holiday comparison
  # unlike school week comparison where individual Monday to Monday etc. adjustments
  # can be made, holidays have odd combinations of weekdays and so can't be simplistically matched
  # in the same way, so temperature compensate the previous holiday to the average temperature
  # of the current holiday
  private def calculate_average_previous_period_temperature
    _current_period, previous_period = last_two_periods(@asof_date)
    @school.temperatures.average_temperature_in_date_range(previous_period.start_date, previous_period.end_date)
  end

  def total_previous_period_unadjusted_values(data_type)
    _current_period, previous_period = last_two_periods(@asof_date)
    aggregate_meter.amr_data.kwh_date_range(previous_period.start_date, previous_period.end_date, data_type, community_use: community_use)
  end

  def set_previous_period_unadjusted_kwh_£_co2_variables
    @total_previous_period_unadjusted_kwh = total_previous_period_unadjusted_values(:kwh)
    @total_previous_period_unadjusted_£   = total_previous_period_unadjusted_values(:£)
    @total_previous_period_unadjusted_co2 = total_previous_period_unadjusted_values(:co2)
  end
end
