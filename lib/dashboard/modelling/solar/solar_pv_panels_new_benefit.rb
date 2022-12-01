class SolarPVPanelsNewBenefit
  include Logging
  def annual_predicted_pv_totals_fast(electricity_amr, meter_collection, start_date, end_date, kwp)
    create_solar_pv_data_fast_summary(electricity_amr, meter_collection, start_date, end_date, kwp)
  end

  def average_annual_yield_x48_deprecated(electricity_amr, meter_collection, start_date, end_date)
    culmulative_yield_x48 = AMRData.one_day_zero_kwh_x48
    culmulative_yield_count = 0

    (start_date..end_date).each do |date|
      pv_yield_x48 = meter_collection.solar_pv[date]
      next if pv_yield_x48.nil?
      culmulative_yield_x48 = AMRData.fast_add_x48_x_x48(culmulative_yield_x48, pv_yield_x48)
      culmulative_yield_count += 1
    end

    AMRData.fast_multiply_x48_x_scalar(culmulative_yield_x48, 1.0 / culmulative_yield_count)
  end

  private

  def create_solar_pv_data_fast_summary(electricity_amr, meter_collection, start_date, end_date, kwp)
    logger.info 'Simulating half hourly benefit of new solar pv panels'

    latest_tariff_£_per_kwh_x48 = electricity_amr.economic_cost_£_per_kwh_x48(end_date)

    solar_pv_output_total             = 0.0
    exported_solar_pv_total           = 0.0
    solar_pv_consumed_onsite_total    = 0.0
    new_mains_consumption_total       = 0.0
    solar_pv_consumed_onsite_total_£  = 0.0
    new_mains_consumption_total_£     = 0.0

    logger.info "PV date range #{meter_collection.solar_pv.start_date} to #{meter_collection.solar_pv.end_date}"

    (start_date..end_date).each do |date|
      pv_yield_x48 = meter_collection.solar_pv[date]
      next if pv_yield_x48.nil?

      (0..47).each do |hhi|
        pv_kwh_hh = pv_yield_x48[hhi] * kwp / 2.0
        existing_mains_kwh_hh   = electricity_amr.kwh(date, hhi)
        existing_mains_kwh_hh_£ = electricity_amr.kwh(date, hhi, :£current)
        implied_rate_£_per_kwh = existing_mains_kwh_hh == 0.0 ? 0.0 : existing_mains_kwh_hh_£ / existing_mains_kwh_hh

        exported_kwh_hh              = [existing_mains_kwh_hh - pv_kwh_hh, 0.0].min.magnitude
        new_mains_consumption_kwh_hh = [existing_mains_kwh_hh - pv_kwh_hh, 0.0].max
        pv_consumed_onsite_kwh_hh    = existing_mains_kwh_hh - new_mains_consumption_kwh_hh

        solar_pv_output_total           += pv_kwh_hh
        exported_solar_pv_total         += exported_kwh_hh
        solar_pv_consumed_onsite_total  += pv_consumed_onsite_kwh_hh
        new_mains_consumption_total     += new_mains_consumption_kwh_hh
        new_mains_consumption_total_£   += new_mains_consumption_kwh_hh * implied_rate_£_per_kwh
      end
    end

    {
      new_mains_consumption:    new_mains_consumption_total,
      new_mains_consumption_£:  new_mains_consumption_total_£,
      solar_consumed_onsite:    solar_pv_consumed_onsite_total,
      exported:                 exported_solar_pv_total,
      solar_pv_output:          solar_pv_output_total
    }
  end
end
