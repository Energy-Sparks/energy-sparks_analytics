require_relative 'alert_analysis_base.rb'

class AlertGasOnlyBase < AlertAnalysisBase
  def initialize(school, report_type)
    super(school, report_type)
  end

  def maximum_alert_date
    @school.aggregated_heat_meters.amr_data.end_date
  end

  def needs_electricity_data?
    false
  end
end