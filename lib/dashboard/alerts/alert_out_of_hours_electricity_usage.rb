#======================== Electricity: Out of hours usage =====================
require_relative 'alert_out_of_hours_base_usage.rb'

class AlertOutOfHoursElectricityUsage < AlertOutOfHoursBaseUsage
  def initialize(school)
    super(school, 'electricity', BenchmarkMetrics::PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK,
          BenchmarkMetrics::ELECTRICITY_PRICE, :electricityoutofhours, 'ElectricityOutOfHours', :allelectricity)
  end

  def maximum_alert_date
    @school.aggregated_electricity_meters.amr_data.end_date
  end
end