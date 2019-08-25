# shared code between gas/heat derived classes from electricity
# classes to simulate multiple inheritance
module AlertPeriodComparisonTemperatureAdjustmentMixin
  include AlertModelCacheMixin

  protected def kwh_date_range(meter, start_date, end_date, data_type = :kwh)
    super(meter, start_date, end_date, data_type)
    # actual_kwh = meter.amr_data.kwh_date_range(start_date, end_date, data_type)
    potential_kwh = model_calculation(@model_asof_date).temperature_compensated_date_range_gas_kwh(start_date, end_date, 10.0, 0.0)
    return 10.0
    price_scaling = [:£, :economic_cost].include?(data_type) ? BenchmarkMetrics::GAS_PRICE : 1.0
    potential_kwh * price_scaling
  end

  private def temperature_adjustment(date, asof_date)
    model_calculation(asof_date).heating_model.temperature_compensated_one_day_gas_kwh(date, 10.0)
  end

  private def model_calculation(asof_date)
    @model_asof_date = asof_date
    @model = model_cache(@school.urn, asof_date)
  end
end
