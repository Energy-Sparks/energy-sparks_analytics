#======================== Change in Electricity Baseload Analysis =============
require_relative 'alert_electricity_baseload_versus_benchmark.rb'

class AlertChangeInElectricityBaseloadShortTerm < AlertElectricityBaseloadVersusBenchmark
  MAXBASELOADCHANGE = 1.15

  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    avg_baseload = average_baseload(asof_date - 365, asof_date)
    last_weeks_baseload = average_baseload(asof_date - 7, asof_date)

    report = AlertReport.new(:baseloadchangeshortterm)
    report.term = :shortterm
    report.add_book_mark_to_base_url('ElectricityBaseload')

    if last_weeks_baseload > avg_baseload * MAXBASELOADCHANGE
      report.summary = 'Your electricity baseload has increased'
      text = sprintf('Your electricity baseload has increased from %.1f kW', avg_baseload)
      text += sprintf('over the last year to %.1f last week. ', last_weeks_baseload)
      cost = BenchmarkMetrics::ELECTRICITY_PRICE * 365.0 * 24 * (last_weeks_baseload - avg_baseload)
      text += sprintf('If this continues it will costs you an additional £%.0f over the next year', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your electricity baseload is good'
      text = sprintf('Your baseload electricity was %.2f kW this week ', last_weeks_baseload)
      text += sprintf('compared with an average of %.2f kW over the last year', avg_baseload)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end
end