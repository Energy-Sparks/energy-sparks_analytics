#======================== Gas: Out of hours usage =============================
require_relative 'alert_out_of_hours_base_usage.rb'

class AlertOutOfHoursGasUsage < AlertOutOfHoursBaseUsage
  def initialize(school)
    super(school, 'gas', BenchmarkMetrics::PERCENT_GAS_OUT_OF_HOURS_BENCHMARK,
          BenchmarkMetrics::GAS_PRICE, :gasoutofhours, 'GasOutOfHours', :allheat)
  end

  def maximum_alert_date
    @school.aggregated_heat_meters.amr_data.end_date
  end

  def needs_electricity_data?
    false
  end
end