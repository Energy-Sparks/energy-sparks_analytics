require_relative 'alert_analysis_base.rb'

class AlertElectricityOnlyBase < AlertAnalysisBase
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
    kwh * blended_electricity_£_per_kwh(asof_date)
  end

  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end

  def blended_electricity_£_per_kwh(asof_date)
    rate = MeterTariffs::DEFAULT_ELECTRICITY_ECONOMIC_TARIFF
    if @school.aggregated_electricity_meters.amr_data.economic_tariff.differential_tariff?(asof_date)
      # assume its been on a differential tariff for the period
      # a slightly false assumption but it might be slow to recalculate
      # the cost for the whole period looking up potentially different tariffs
      # on different days
      rate = MeterTariffs::BLENDED_DIFFERNTIAL_RATE_APPROX
    end
    rate
  end

  def needs_gas_data?
    false
  end
end