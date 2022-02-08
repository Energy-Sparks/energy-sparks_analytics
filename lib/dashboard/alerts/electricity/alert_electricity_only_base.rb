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

  protected

  def baseload_calculator(meter = aggregate_meter)
    @baseload_calculator ||= ElectricityBaseloadAnalysis.new(meter)
  end

  def average_baseload(date1, date2, meter = aggregate_meter)
    baseload_calculator(meter).average_baseload(date1, date2)
  end

  def average_baseload_kw(asof_date, meter = aggregate_meter)
    baseload_calculator(meter).average_baseload_kw(asof_date)
  end

  def annual_average_baseload_kwh(asof_date, meter = aggregate_meter)
    baseload_calculator(meter).annual_average_baseload_kwh(asof_date)
  end

  def annual_average_baseload_£(asof_date, meter = aggregate_meter)
    kwh = annual_average_baseload_kwh(asof_date, meter)
    kwh * blended_electricity_£_per_kwh
  end

  def annual_average_baseload_co2(asof_date, meter = aggregate_meter)
    kwh = annual_average_baseload_kwh(asof_date, meter)
    kwh * blended_co2_per_kwh
  end

  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
  
  def needs_gas_data?
    false
  end
end
