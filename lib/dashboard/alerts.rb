
require 'html-table'
# rubocop:disable Metrics/LineLength, Style/FormatStringToken, Style/FormatString, Lint/UnneededDisable
#
# Alerts: Energy Sparks alerts
#         this is a mix of short-term alerts e.g. your energy consumption has gone up since last week
#         and longer term alerts - energy assessments e.g. your energy consumption at weekends it high
#
# the current code strcucture consists of an alert base class from which individual classes analysing
# different aspect of energy consumption are derived
#
# plus a reporting class for alerts which can return a mixture of text, html, charts etc., although
# much of the potential complexity of this framework will not be implemented in the first iteration
#

class AlertAnalysisBase
  attr_reader :analysis_report
  def initialize(school)
    @school = school
    @report = nil
  end

  def analyse(_asof_date)
    raise 'Error: incorrect attempt to use abstract base class'
  end

  def add_report(report)
    @analysis_report = report
  end

  def pupils
    @school.pupils
  end

  def floor_area
    @school.floor_area
  end

  def school_type
    @school.school_type
  end

  # returns a list of the last n 'school_days' before and including the asof_date
  def last_n_school_days(asof_date, school_days)
    list_of_school_days = []
    while school_days > 0
      unless @school.holidays.holiday?(asof_date) || asof_date.saturday? || asof_date.sunday?
        list_of_school_days.push(asof_date)
        school_days -= 1
      end
      asof_date -= 1
    end
    list_of_school_days.sort
  end
end

# simple placeholder class for holding detail of description results
# type:   :text (a string), :html (snippet), :chart (chart as an example of alert issue)
class AlertDescriptionDetail
  attr_reader :type, :content
  def initialize(type, content)
    @type = type
    @content = content
  end
end

# class containing descriptive results of alerts
# - type:     enumeration of type of analysis, tied in to a specific analysis class (see base class above)
# - summary:  a brief descriptive summary of the issue (text)
# - term:     :short, :medium, :long_term
# - help_url: an optional link to further information on interpreting the alert
# - detail:   an array of AlertDescriptionDetail - potential mixed media results e.g. text, then html, then a chart
# - rating:   on this metric out of 10
# - status:   :good, :ok, :poor (only expecting to report ':poor' alerts, the rest are for information)
class AlertReport
  ALERT_HELP_URL = 'http://blog.energysparks.uk/alerts'.freeze
  MAX_RATING = 10.0
  attr_accessor :type, :summary, :term, :help_url, :detail, :rating, :status
  def initialize(type)
    @type = type
    @detail = []
  end

  def add_book_mark_to_base_url(bookmark)
    @help_url = ALERT_HELP_URL + '#' + bookmark
  end

  def add_detail(detail)
    @detail.push(detail)
  end

  def to_s
    out =  sprintf("%-20s%s\n", 'Type:', @type)
    out += sprintf("%-20s%s\n", 'Summary:', @summary)
    out += sprintf("%-20s%s\n", 'Term:', @term)
    out += sprintf("%-20s%s\n", 'URL:', @help_url)
    out += sprintf("%-20s%s\n", 'Rating:', @rating.nil? ? 'unrated' : @rating.round(0))
    @detail.each do |info|
      out += sprintf("%-20s%s\n", 'Detail: type', info.type)
      out += sprintf("%-20s%s\n", '', info.content)
    end
    out += sprintf("%-20s%s\n", 'Status:', @status)
    out
  end
end

#======================== Electricity Baseload Analysis Versus Benchmark =====
class AlertElectricityBaseloadVersusBenchmark < AlertAnalysisBase
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    avg_baseload = average_baseload(asof_date - 365, asof_date)
    benchmark_per_pupil = BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
    benchmark_per_floor_area = BenchmarkMetrics.recommended_baseload_for_floor_area(floor_area, school_type)

    report = AlertReport.new(:baseloadbenchmark)
    report.term = :longterm
    report.add_book_mark_to_base_url('ElectricityBaseload')

    if avg_baseload > benchmark_per_pupil || avg_baseload > benchmark_per_floor_area
      report.summary = 'Your electricity baseload is too high'
      text = commentary(avg_baseload, 'too high', benchmark_per_pupil, benchmark_per_floor_area)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = avg_baseload / benchmark_per_pupil
      per_floor_area_ratio = avg_baseload / benchmark_per_floor_area
      report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      report.status = :poor
    else
      report.summary = 'Your electricity baseload is good'
      text = commentary(avg_baseload, 'good', benchmark_per_pupil, benchmark_per_floor_area)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end

  def commentary(baseload, comparative_text, pupil_benchmark, floor_area_benchmark)
    text =  sprintf('Your baseload over the last year of %.1f kW is %s, ', baseload, comparative_text)
    text += sprintf('compared with benchmarks of %.1f kW (pupil based) ', pupil_benchmark)
    text += sprintf('and %.1f kW (floor area based) ', floor_area_benchmark)
    text
  end

  def average_baseload(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.average_baseload_kw_date_range(date1, date2)
  end
end

#======================== Change in Electricity Baseload Analysis =============
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
      text =  sprintf('Your baseload electricity was %.2f kW this week ', last_weeks_baseload)
      text += sprintf('compared with an average of %.2f kW over the last year', avg_baseload)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end
end

#======================== Change in Daily Electricity Consumption =============
class AlertChangeInDailyElectricityShortTerm < AlertAnalysisBase
  MAXDAILYCHANGE = 1.15
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    days_in_week = 5
    beginning_of_week, last_weeks_consumption = schoolday_energy_usage_over_period(asof_date, days_in_week)
    beginning_of_last_week, week_befores_consumption = schoolday_energy_usage_over_period(beginning_of_week - 1, days_in_week)

    report = AlertReport.new(:changeinelectricityconsumption)
    report.term = :shortterm
    report.add_book_mark_to_base_url('ElectricityChange')

    if last_weeks_consumption > week_befores_consumption * MAXDAILYCHANGE
      report.summary = 'Your daily electricity consumption has increased'
      text = sprintf('Your electricity consumption has increased from %.0f kWh ', week_befores_consumption)
      text += sprintf('last week (5 school days following %s) ', beginning_of_last_week.strptime('%d %m'))
      text += sprintf('to %.0f kWh ', last_weeks_consumption)
      text += sprintf('this week (5 school days following %s)', beginning_of_week)
      text += sprintf('over the last year to %.1f last week. ', last_weeks_baseload)
      cost = BenchmarkMetrics::ELECTRICITY_PRICE * 195.0 * (last_weeks_consumption - week_befores_consumption) / days_in_week
      text += sprintf('If this continues it will costs you an additional £%.0f over the next year', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your daily electricity consumption is good'
      text =  sprintf('Your weekly school day electricity consumption was %.0f kWh (£%.0f) this week ',
                      last_weeks_consumption,
                      last_weeks_consumption * BenchmarkMetrics::ELECTRICITY_PRICE)
      text += sprintf('compared with %.0f kWh (£%.0f) last week',
                      week_befores_consumption,
                      week_befores_consumption * BenchmarkMetrics::ELECTRICITY_PRICE)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end

  def schoolday_energy_usage_over_period(asof_date, school_days)
    list_of_school_days = last_n_school_days(asof_date, school_days)
    total_kwh = 0.0
    list_of_school_days.each do |date|
      total_kwh += days_energy_consumption(date)
    end
    [list_of_school_days[0], total_kwh]
  end

  def days_energy_consumption(date)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.one_day_kwh(date)
  end
end

#======================== Base: Out of hours usage ============================
class AlertOutOfHoursBaseUsage < AlertAnalysisBase
  include HTML
  def initialize(school, fuel, benchmark_out_of_hours_percent,
                 fuel_cost, alert_type, bookmark, meter_definition)
    super(school)
    @fuel = fuel
    @benchmark_out_of_hours_percent = benchmark_out_of_hours_percent
    @fuel_cost = fuel_cost
    @alert_type = alert_type
    @bookmark = bookmark
    @meter_definition = meter_definition
  end

  def analyse(_asof_date)
    breakdown = out_of_hours_energy_consumption

    kwh_in_hours, kwh_out_of_hours = in_out_of_hours_consumption(breakdown)
    percent = kwh_out_of_hours / (kwh_in_hours + kwh_out_of_hours)

    report = AlertReport.new(@alert_type)
    report.term = :longterm
    report.add_book_mark_to_base_url(@bookmark)

    if percent > @benchmark_out_of_hours_percent
      report.summary = 'You have a high percentage of your ' + @fuel + ' usage outside school hours'
      text =  sprintf('%.0f percent of your ' + @fuel, 100.0 * percent)
      text += ' is used out of hours which is high compared with exemplar schools '
      text += sprintf('which use only %.0f percent out of hours', 100.0 * @benchmark_out_of_hours_percent)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.add_detail(description1)
      description2 = AlertDescriptionDetail.new(:chart, breakdown)
      report.add_detail(description2)
      table_data = convert_breakdown_to_html_compliant_array(breakdown)
      table = Table.new(table_data) # or could use gem Markaby
      description3 = AlertDescriptionDetail.new(:html, table.html)
      report.add_detail(description3)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your out of hours ' + @fuel + ' consumption is good'
      text = sprintf('Your out of hours ' + @fuel + ' consumption is good at %.0f percent', 100.0 * percent)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.add_detail(description1)
      report.rating = 10.0
      report.status = :good
    end
    add_report(report)
  end

  def convert_breakdown_to_html_compliant_array(breakdown)
    html_table = []
    breakdown[:x_data].each do |daytype, consumption|
      formatted_consumption = sprintf('%.0f kWh/£%.0f', consumption[0], consumption[0] * @fuel_cost)
      html_table.push([daytype, formatted_consumption])
    end
    html_table
  end

  def in_out_of_hours_consumption(breakdown)
    kwh_in_hours = 0.0
    kwh_out_of_hours = 0.0
    breakdown[:x_data].each do |daytype, consumption|
      if daytype == SeriesNames::SCHOOLDAYOPEN
        kwh_in_hours += consumption[0]
      else
        kwh_out_of_hours += consumption[0]
      end
    end
    [kwh_in_hours, kwh_out_of_hours]
  end

  def out_of_hours_energy_consumption
    daytype_breakdown = {
      name:             'Day Type',
      chart1_type:      :pie,
      series_breakdown: :daytype,
      yaxis_units:      :money,
      meter_definition: @meter_definition,
      x_axis:           :nodatebuckets,
      timescale:        :year
    }

    # use the chart manager (and aggregator) to produce the breakdown
    chart = ChartManager.new(@school)
    result = chart.run_chart(daytype_breakdown)

    puts result.inspect
    result
  end
end

#======================== Electricity: Out of hours usage =====================

class AlertOutOfHoursElectricityUsage < AlertOutOfHoursBaseUsage
  def initialize(school)
    super(school, 'electricity', BenchmarkMetrics::PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK,
      BenchmarkMetrics::ELECTRICITY_PRICE, :electricityoutofhours, 'ElectricityOutOfHours', :allelectricity)
  end
end

#======================== Gas: Out of hours usage =============================

class AlertOutOfHoursGasUsage < AlertOutOfHoursBaseUsage
  def initialize(school)
    super(school, 'gas', BenchmarkMetrics::PERCENT_GAS_OUT_OF_HOURS_BENCHMARK,
      BenchmarkMetrics::GAS_PRICE, :gasoutofhours, 'GasOutOfHours', :allheat)
  end
end

#======================== Electricity Annual kWh Versus Benchmark =============
class AlertElectricityAnnualVersusBenchmark < AlertAnalysisBase
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    annual_kwh = kwh(asof_date - 365, asof_date)
    annual_kwh_per_pupil_benchmark = BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * @school.pupils
    annual_kwh_per_floor_area_benchmark = BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_M2 * @school.floor_area

    report = AlertReport.new(:annualelectricitybenchmark)
    report.term = :longterm
    report.add_book_mark_to_base_url('AnnualElectricity')

    if annual_kwh > annual_kwh_per_pupil_benchmark || annual_kwh > annual_kwh_per_floor_area_benchmark
      report.summary = 'Your annual electricity usage is high compared with the average school'
      text = commentary(annual_kwh, 'too high', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = annual_kwh / annual_kwh_per_pupil_benchmark
      per_floor_area_ratio = annual_kwh / annual_kwh_per_floor_area_benchmark
      report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      report.status = :poor
    else
      report.summary = 'Your electricity baseload is good'
      text = commentary(avg_baseload, 'good', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end

  def commentary(annual_kwh, comparative_text, pupil_benchmark, floor_area_benchmark)
    annual_cost = annual_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    benchmark_pupil_cost = pupil_benchmark * BenchmarkMetrics::ELECTRICITY_PRICE
    benchmark_m2_cost = floor_area_benchmark * BenchmarkMetrics::ELECTRICITY_PRICE
    text = 'Your annual electricity usage ' +  comparative_text
    text += sprintf('Your electricity usage over the last year of %.0f kWh/£%.0f is %s, ', annual_kwh, annual_cost, comparative_text)
    text += sprintf('compared with benchmarks of %.0f kWh/£%.0f (pupil based) ', pupil_benchmark, benchmark_pupil_cost)
    text += sprintf('and %.0f kWh/£%.0f (floor area based) ', floor_area_benchmark, benchmark_m2_cost)
    text
  end

  def kwh(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.kwh_date_range(date1, date2)
  end
end

#==============================================================================
#==============================================================================
#========================HEATING/GAS===========================================
#==============================================================================
#==============================================================================
#==============================================================================

#======================== Gas Annual kWh Versus Benchmark =====================
# currently not derived from a common base class with electricity as we may need
# to tmperature adjust in future
class AlertGasAnnualVersusBenchmark < AlertAnalysisBase
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    annual_kwh = kwh(asof_date - 365, asof_date)
    annual_kwh_per_pupil_benchmark = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_PUPIL * @school.pupils
    annual_kwh_per_floor_area_benchmark = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * @school.floor_area

    report = AlertReport.new(:annualgasbenchmark)
    report.term = :longterm
    report.add_book_mark_to_base_url('AnnualGasBenchmark')

    if annual_kwh > annual_kwh_per_pupil_benchmark ||
        annual_kwh > annual_kwh_per_floor_area_benchmark
      report.summary = 'Your annual gas consumption is high compared with the average school'
      text = commentary(annual_kwh, 'too high', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = annual_kwh / annual_kwh_per_pupil_benchmark
      per_floor_area_ratio = annual_kwh / annual_kwh_per_floor_area_benchmark
      report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      report.status = :poor
    else
      report.summary = 'Your gas consumption is good'
      text = commentary(avg_baseload, 'good', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end

  def commentary(annual_kwh, comparative_text, pupil_benchmark, floor_area_benchmark)
    annual_cost = annual_kwh * BenchmarkMetrics::GAS_PRICE
    benchmark_pupil_cost = pupil_benchmark * BenchmarkMetrics::GAS_PRICE
    benchmark_m2_cost = floor_area_benchmark * BenchmarkMetrics::GAS_PRICE
    text = 'Your annual gas usage ' + comparative_text
    text += sprintf('Your gas usage over the last year of %.0f kWh/£%.0f is %s, ', annual_kwh, annual_cost, comparative_text)
    text += sprintf('compared with benchmarks of %.0f kWh/£%.0f (pupil based) ', pupil_benchmark, benchmark_pupil_cost)
    text += sprintf('and %.0f kWh/£%.0f (floor area based) ', floor_area_benchmark, benchmark_m2_cost)
    text
  end

  def kwh(date1, date2)
    amr_data = @school.aggregated_heating_meters.amr_data
    amr_data.kwh_date_range(date1, date2)
  end
end

#================= Base Class for Gas Alerts including model usage=============
class AlertGasModelBase < AlertAnalysisBase
  MAX_CHANGE_IN_PERCENT = 0.15
  def initialize(school)
    super(school)
    @heating_model = nil
  end

  def schoolday_energy_usage_over_period(asof_date, school_days)
    total_kwh = 0.0
    while school_days > 0
      unless @school.holidays.holiday?(asof_date) || asof_date.saturday? || asof_date.sunday?
        total_kwh += days_energy_consumption(asof_date)
        school_days -= 1
      end
      asof_date -= 1
    end
    [asof_date, total_kwh]
  end

  def days_energy_consumption(date)
    amr_data = @school.aggregated_heating_meters.amr_data
    amr_data.one_day_kwh(date)
  end

  def calculate_model(asof_date)
    one_year_before_asof_date = asof_date - 365
    period = SchoolDatePeriod.new(:alert, 'Current Year', one_year_before_asof_date, asof_date)
    @heating_model = @school.heating_model(period)
    @heating_model.calculate_heating_periods(one_year_before_asof_date, asof_date)
  end
end

#======================== Change in Daily Gas Consumption =====================
# more complicated than the electricity case as you need to adjust for
# for temperature and take into account the heating turning on and off
# TODO(PH,20May2018) take into account heating turning on and off
class AlertChangeInDailyGasShortTerm < AlertGasModelBase
  MAX_CHANGE_IN_PERCENT = 0.15
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)

    this_weeks_school_days = last_n_school_days(asof_date, 5)
    last_weeks_school_days = last_n_school_days(this_weeks_school_days[0] - 1, 5)

    predicted_kwh_this_week = @heating_model.predicted_kwh_list_of_dates(this_weeks_school_days, @school.temperatures)
    predicted_kwh_last_week = @heating_model.predicted_kwh_list_of_dates(last_weeks_school_days, @school.temperatures)
    predicted_changein_kwh = predicted_kwh_this_week - predicted_kwh_last_week
    predicted_percent_increase_in_usage = predicted_changein_kwh / predicted_kwh_last_week

    actual_kwh_this_week = @school.aggregated_heating_meters.amr_data.kwh_date_list(this_weeks_school_days)
    actual_kwh_last_week = @school.aggregated_heating_meters.amr_data.kwh_date_list(last_weeks_school_days)
    actual_changein_kwh = actual_kwh_this_week - actual_kwh_last_week
    actual_percent_increase_in_usage = actual_changein_kwh / actual_kwh_last_week

    this_week_cost = BenchmarkMetrics::GAS_PRICE * actual_kwh_this_week
    last_week_cost = BenchmarkMetrics::GAS_PRICE * actual_kwh_last_week

    difference_in_actual_versus_predicted_change_percent = actual_percent_increase_in_usage - predicted_percent_increase_in_usage

    report = AlertReport.new(:changeingasconsumption)
    report.term = :shortterm
    report.add_book_mark_to_base_url('GasChange')

    comparison_commentary  = sprintf('This week your gas consumption was %.0f kWh/£%.0f (predicted %.0f kWh) ', actual_kwh_this_week, this_week_cost, predicted_kwh_this_week)
    comparison_commentary += sprintf('compared with %.0f kWh/£%.0f (predicted %.0f kWh) last week', actual_kwh_last_week, last_week_cost, predicted_kwh_last_week)

    if difference_in_actual_versus_predicted_change_percent > MAX_CHANGE_IN_PERCENT
      report.summary = 'Your weekly gas consumption has increased more than expected'
      text = comparison_commentary
      cost = BenchmarkMetrics::GAS_PRICE * (actual_changein_kwh - predicted_changein_kwh)
      text += sprintf('This has cost the school about £%.0f', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your weekly gas consumption is good'
      text = comparison_commentary
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end
end

#======================== Weekend Gas Consumption =============================
# gas shouldn't be consumed at weekends, apart for from frost protection
class AlertWeekendGasConsumptionShortTerm < AlertGasModelBase
  MAX_COST = 2.5 # £2.5 limit
  FROST_PROTECTION_TEMPERATURE = 4
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    weekend_dates = previous_weekend_dates(asof_date)
    weekend_kwh = kwh_usage_outside_frost_period(weekend_dates, FROST_PROTECTION_TEMPERATURE)
    weekend_cost = BenchmarkMetrics::GAS_PRICE * weekend_kwh
    usage_text = sprintf('%.0f kWh/£%.0f', weekend_kwh, weekend_cost)

    report = AlertReport.new(:weekendgasconsumption)
    report.term = :shortterm
    report.add_book_mark_to_base_url('WeekendGas')

    if weekend_cost > MAX_COST
      report.summary = 'Your weekend gas consumption was more than expected'
      text = 'Your weekend gas consumption was more than expected at ' + usage_text
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your weekend gas consumption was good'
      text = 'Your weekend gas consumption was ' + usage_text
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good
    end
    report.add_detail(description1)
    add_report(report)
  end

  def previous_weekend_dates(asof_date)
    weekend_dates = []
    while weekend_dates.length < 2
      if asof_date.saturday? || asof_date.sunday?
        weekend_dates.push(asof_date)
      end
      asof_date -= 1
    end
    weekend_dates.sort
  end

  def kwh_usage_outside_frost_period(dates, frost_protection_temperature)
    total_kwh = 0.0
    dates.each do |date|
      (0..47).each do |halfhour_index|
        if @school.temperatures.get_temperature(date, halfhour_index) > frost_protection_temperature
          total_kwh += @school.aggregated_heating_meters.amr_data.kwh(date, halfhour_index)
        end
      end
    end
    total_kwh
  end
end

#======================== Holiday Alert =======================================
class AlertImpendingHoliday < AlertAnalysisBase
  WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD = 2
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    report = AlertReport.new(:upcomingholiday)
    report.add_book_mark_to_base_url('UpcomingHoliday')
    report.term = :shortterm

    if !@school.holidays.holiday?(asof_date) && upcoming_holiday?(asof_date, WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD)
      report.summary = 'There is an upcoming holiday - please turn heating, hot water and appliances off'
      text = 'There is a holiday coming up'
      text += 'please ensure all unnecessary appliances are switched off,'
      text += 'including heating and hot water (but remember to flush when turned back on)'
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'There is no upcoming holiday, no action needs to be taken'
      text = ''
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  def upcoming_holiday?(asof_date, num_days)
    asof_date += 1
    while num_days > 0
      unless asof_date.saturday? || asof_date.sunday?
        num_days -= 1
        return true if @school.holidays.holiday?(asof_date)
      end
      asof_date += 1
    end
    false
  end
end

#======================== Turn Heating On/Off ==================================
# looks at the forecast to determine whether it is a good idea to turn the
# the heating on/off
# TODO(PH,30May2018) - improve heuristics of decision, perhaps find better way
#                    - of determining whether heating is on or off
#                    - currently this is based on a live forecast but the
#                    - AMR data might be several days out of date?
class AlertHeatingOnOff < AlertGasModelBase
  FORECAST_DAYS_LOOKAHEAD = 5
  AVERAGE_TEMPERATURE_LIMIT = 14
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)
    heating_on = @heating_model.heating_on?(asof_date) # potential timing problem if AMR data not up to date
    @yahoo_forecast = YahooWeatherForecast.new('bath, uk')

    report = AlertReport.new(:turnheatingonoff)
    report.add_book_mark_to_base_url('TurnHeatingOnOff')
    report.term = :shortterm

    if heating_on && average_temperature_in_period > AVERAGE_TEMPERATURE_LIMIT
      report.summary = 'The average temperature over the next few days is high enough to consider switching the heating off'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      report.rating = 5.0
      report.status = :poor
    elsif !heating_on && average_temperature_in_period < AVERAGE_TEMPERATURE_LIMIT
      report.summary = 'The average temperature over the next few days is low enough to consider switching the heating on'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      report.rating = 5.0
      report.status = :poor
    else
      report.summary = 'No change is necessary to the heating system'
      text = ''
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  def dates_and_temperatures_display
    display = ''
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    @yahoo_forecast.forecast.each do |date, temperatures|
      _low, avg_temp, _high = temperatures
      display += date.strftime('%A') + '(' + avg_temp.to_s + 'C) '
      forecast_limit_days -= 1
      return display if forecast_limit_days.zero?
    end
    display
  end

  def average_temperature_in_period
    temperature_sum = 0.0
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    @yahoo_forecast.forecast.each_value do |temperatures|
      _low, avg_temp, _high = temperatures
      temperature_sum += avg_temp
      forecast_limit_days -= 1
      return temperature_sum / FORECAST_DAYS_LOOKAHEAD if forecast_limit_days.zero?
    end
    nil
  end
end

#======================== Hot Water Efficiency =================================
class AlertHotWaterEfficiency < AlertGasModelBase
  MIN_EFFICIENCY = 0.7
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_hot_water_model(asof_date)
    efficiency = @hot_water_model.efficiency

    report = AlertReport.new(:hotwaterefficiency)
    report.add_book_mark_to_base_url('HotWaterEfficiency')
    report.term = :longterm

    if efficiency < MIN_EFFICIENCY
      report.summary = 'Inefficient hot water system'
      text = 'Your hot water system appears to be only '
      text += sprintf('%.0f percent efficient', efficiency * 100.0)
      report.rating = 10.0 * (efficiency / 0.85)
      report.status = :poor
    else
      report.summary = 'Your hot water system is efficient'
      text = 'Your hot water system appears is '
      text += sprintf('%.0f percent efficient, which is very good', efficiency * 100.0)
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  def calculate_hot_water_model(_as_of_date)
    @hot_water_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@school)
  end
end

#======================== Heating coming on too early in morning ==============
class AlertHeatingComingOnTooEarly < AlertGasModelBase
  FROST_PROTECTION_TEMPERATURE = 4
  MAX_HALFHOURS_HEATING_ON = 10
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)
    heating_on = @heating_model.heating_on?(asof_date) # potential timing problem if AMR data not up to date

    report = AlertReport.new(:heatingcomingontooearly)
    report.add_book_mark_to_base_url('HeatingComingOnTooEarly')
    report.term = :shortterm

    if heating_on
      halfhour_index = calculate_heating_on_time(asof_date, FROST_PROTECTION_TEMPERATURE)
      time_str = halfhour_index_to_timestring(halfhour_index)

      if halfhour_index < MAX_HALFHOURS_HEATING_ON
        report.summary = 'Your heating is coming on too early'
        text = 'Your heating came on at ' + time_str + ' on ' + asof_date.strftime('%d %b %Y')
        report.rating = 2.0
        report.status = :poor
      else
        report.summary = 'Your heating is coming on at a reasonable time in the morning'
        text = 'Your heating came on at ' + time_str + ' on ' + asof_date.strftime('%d %b %Y')
        report.rating = 10.0
        report.status = :good
      end
    else
      report.summary = 'Check on time heating system is coming on'
      text = 'Your heating system is currently not turned on'
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  # calculate when the heating comes on, using an untested heuristic to
  # determine when the heating has come on (usage > average daily usage)
  def calculate_heating_on_time(asof_date, frost_protection_temperature)
    daily_kwh = @school.aggregated_heating_meters.amr_data.one_day_kwh(asof_date)
    average_half_hourly_kwh = daily_kwh / 48.0
    (0..47).each do |halfhour_index|
      if @school.temperatures.get_temperature(asof_date, halfhour_index) > frost_protection_temperature &&
          @school.aggregated_heating_meters.amr_data.kwh(asof_date, halfhour_index) > average_half_hourly_kwh
        return halfhour_index
      end
    end
    nil
  end

  def halfhour_index_to_timestring(halfhour_index)
    hour = (halfhour_index / 2).to_s
    minutes = (halfhour_index / 2).floor.odd? ? '30' : '00'
    hour + ':' + minutes # hH:MM
  end
end

#======================== Poor thermostatic control ==============
class AlertThermostaticControl < AlertGasModelBase
  MIN_R2 = 0.8
  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)

    report = AlertReport.new(:thermostaticcontrol)
    report.add_book_mark_to_base_url('ThermostaticControl')
    report.term = :longterm

    r2 = @heating_model.models[:heating_occupied].r2

    if r2 < MIN_R2
      report.summary = 'Thermostatic control of the school is poor'
      text = 'The thermostatic control of the heating at the school appears poor '
      text += sprintf('at an R2 of %.2f ', r2)
      text += sprintf('the school should aim to improve this to above %.2f', MIN_R2)
      report.rating = r2 * 10.0
      report.status = :poor
    else
      report.summary = 'Thermostatic control of the school is good'
      text = 'The thermostatic control of the heating is good  '
      text += sprintf('at an R2 of %.2f', r2)
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end
end
# rubocop:enable Metrics/LineLength, Style/FormatStringToken, Style/FormatString, Lint/UnneededDisable
