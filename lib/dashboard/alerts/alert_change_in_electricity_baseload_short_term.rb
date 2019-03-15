#======================== Change in Electricity Baseload Analysis =============
require_relative 'alert_electricity_only_base.rb'

class AlertChangeInElectricityBaseloadShortTerm < AlertElectricityOnlyBase
  MAXBASELOADCHANGE = 1.15

  def initialize(school)
    super(school, :baseloadchangeshortterm)
  end

  def analyse_private(asof_date)
    avg_baseload, days_sample = baseload(asof_date)
    last_weeks_baseload = average_baseload(asof_date - 7, asof_date)

    @analysis_report.term = :shortterm
    @analysis_report.add_book_mark_to_base_url('ElectricityBaseload')

    if last_weeks_baseload > avg_baseload * MAXBASELOADCHANGE
      @analysis_report.summary = 'Your electricity baseload has increased'
      text = sprintf('Your electricity baseload has increased from %.1f kW ', avg_baseload)
      text += sprintf('over the last year to %.1f kW last week. ', last_weeks_baseload)
      cost = BenchmarkMetrics::ELECTRICITY_PRICE * 365.0 * 24 * (last_weeks_baseload - avg_baseload)
      text += sprintf('If this continues it will costs you an additional £%.0f over the next year.', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your electricity baseload is good'
      text = sprintf('Your baseload electricity was %.2f kW this week ', last_weeks_baseload)
      text += sprintf('compared with an average of %.2f kW over the last year.', avg_baseload)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end
end