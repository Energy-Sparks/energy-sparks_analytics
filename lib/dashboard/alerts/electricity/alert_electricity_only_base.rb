require_relative '../common/alert_analysis_base.rb'

class AlertElectricityOnlyBase < AlertAnalysisBase
  include ElectricityCostCo2Mixin
  def initialize(school, _report_type)
    super(school, _report_type)
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
  end

  def time_of_year_relevance
    set_time_of_year_relevance(5.0)
  end

  def aggregate_meter
    @school.aggregated_electricity_meters
  end

  protected

  def needs_gas_data?
    false
  end
end
