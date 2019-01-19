#======================== Change in Daily Gas Consumption =====================
# more complicated than the electricity case as you need to adjust for
# for temperature and take into account the heating turning on and off
# TODO(PH,20May2018) take into account heating turning on and off
require_relative 'alert_gas_model_base.rb'

class AlertChangeInDailyGasShortTerm < AlertGasModelBase
  MAX_CHANGE_IN_PERCENT = 0.15

  def initialize(school)
    super(school, :changeingasconsumption)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)

    this_weeks_school_days = last_n_school_days(asof_date, 5)
    last_weeks_school_days = last_n_school_days(this_weeks_school_days[0] - 1, 5)

    predicted_kwh_this_week = @heating_model.predicted_kwh_list_of_dates(this_weeks_school_days, @school.temperatures)
    predicted_kwh_last_week = @heating_model.predicted_kwh_list_of_dates(last_weeks_school_days, @school.temperatures)
    predicted_changein_kwh = predicted_kwh_this_week - predicted_kwh_last_week
    predicted_percent_increase_in_usage = predicted_changein_kwh / predicted_kwh_last_week

    actual_kwh_this_week = @school.aggregated_heat_meters.amr_data.kwh_date_list(this_weeks_school_days)
    actual_kwh_last_week = @school.aggregated_heat_meters.amr_data.kwh_date_list(last_weeks_school_days)
    actual_changein_kwh = actual_kwh_this_week - actual_kwh_last_week
    actual_percent_increase_in_usage = actual_changein_kwh / actual_kwh_last_week

    this_week_cost = BenchmarkMetrics::GAS_PRICE * actual_kwh_this_week
    last_week_cost = BenchmarkMetrics::GAS_PRICE * actual_kwh_last_week

    difference_in_actual_versus_predicted_change_percent = actual_percent_increase_in_usage - predicted_percent_increase_in_usage

    @analysis_report.term = :shortterm
    @analysis_report.add_book_mark_to_base_url('GasChange')

    comparison_commentary = sprintf('This week your gas consumption was %.0f kWh/£%.0f (predicted %.0f kWh) ', actual_kwh_this_week, this_week_cost, predicted_kwh_this_week)
    comparison_commentary += sprintf('compared with %.0f kWh/£%.0f (predicted %.0f kWh) last week.', actual_kwh_last_week, last_week_cost, predicted_kwh_last_week)

    if difference_in_actual_versus_predicted_change_percent > MAX_CHANGE_IN_PERCENT
      @analysis_report.summary = 'Your weekly gas consumption has increased more than expected'
      text = comparison_commentary
      cost = BenchmarkMetrics::GAS_PRICE * (actual_changein_kwh - predicted_changein_kwh)
      text += sprintf('This has cost the school about £%.0f', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your weekly gas consumption is good'
      text = comparison_commentary
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end
end