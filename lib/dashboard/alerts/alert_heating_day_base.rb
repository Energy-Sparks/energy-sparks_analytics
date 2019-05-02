class AlertHeatingDaysBase < AlertGasModelBase
  FROST_PROTECTION_TEMPERATURE = 4

  def heating_day_breakdown_current_year(asof_date)
    @breakdown = @heating_model.heating_day_breakdown(asof_date_minus_one_year(asof_date), asof_date) if @breakdown.nil?
    @breakdown
  end

  protected def calculate_heating_off_statistics(asof_date, frost_protection_temperature = FROST_PROTECTION_TEMPERATURE)
    kwh_needed_for_frost_protection = 0.0
    kwh_consumed = 0.0
    start_date = meter_date_one_year_before(aggregate_meter, asof_date)
    (start_date..asof_date).each do |date|
      if !occupied?(date) && @heating_model.heating_on?(date)
        days_kwh_below_frost, days_kwh = days_total_kwh_below_frost(date, frost_protection_temperature)
        kwh_needed_for_frost_protection += days_kwh_below_frost
        kwh_consumed += days_kwh
      end
    end
    [kwh_needed_for_frost_protection, kwh_consumed]
  end

  private def days_total_kwh_below_frost(date, frost_protection_temperature)
    days_kwh_x48 = aggregate_meter.amr_data.days_kwh_x48(date)
    days_temperatures = @school.temperatures.one_days_data_x48(date)
    halfhours_of_frost = days_temperatures.map { |temperature| temperature < frost_protection_temperature ? 1.0 : 0.0 }
    kwh_below_frost_level = AMRData.fast_multiply_x48_x_x48(days_kwh_x48, halfhours_of_frost)
    [kwh_below_frost_level.sum, days_kwh_x48.sum, days_temperatures.sum > 0.0]
  end
end