require_relative 'alert_analysis_base.rb'

class AlertElectricityOnlyBase < AlertAnalysisBase
  def initialize(school, report_type)
    super(school, report_type)
  end

  def maximum_alert_date
    @school.aggregated_electricity_meters.amr_data.end_date
  end

  protected

  def average_baseload(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.average_baseload_kw_date_range(date1, date2)
  end

  def baseload(asof_date)
    start_date = [asof_date - 365, @school.aggregated_electricity_meters.amr_data.start_date].max
    avg_baseload = average_baseload(start_date, asof_date)
    [avg_baseload, asof_date - start_date]
  end
end