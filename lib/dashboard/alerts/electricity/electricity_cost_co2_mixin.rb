module ElectricityCostCo2Mixin
  def blended_electricity_£_per_kwh
    @blended_electricity_£_per_kwh ||= blended_rate(:£)   
  end

  def blended_co2_per_kwh
    @blended_co2_per_kwh ||= blended_rate(:co2)
  end

  # technically imperfect as baseload is 24 hours per day, so equal usage out of peaks hours than in
  # hence this value will probably be higher as demend is higher at peak times, really need to average
  # the £/kWh rate over the period, for CO2 probably similar but to a lesser extent
  def blended_rate(data_type = :£)
    up_to_1_year_ago_start_date = aggregate_meter.amr_data.up_to_1_year_ago
    end_date = aggregate_meter.amr_data.end_date
    up_to_1_year_kwh  = aggregate_meter.amr_data.kwh_date_range(up_to_1_year_ago_start_date, end_date, :kwh)
    up_to_1_year_data = aggregate_meter.amr_data.kwh_date_range(up_to_1_year_ago_start_date, end_date, data_type)
    up_to_1_year_data / up_to_1_year_kwh # will blow up if kWh == 0.0 but that is ok
  end
end
