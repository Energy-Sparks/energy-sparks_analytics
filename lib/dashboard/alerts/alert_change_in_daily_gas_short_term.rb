#======================== Change in Daily Gas Consumption =====================
# more complicated than the electricity case as you need to adjust for
# for temperature and take into account the heating turning on and off
# TODO(PH,20May2018) take into account heating turning on and off
require_relative 'alert_gas_model_base.rb'

class AlertChangeInDailyGasShortTerm < AlertGasModelBase
  include Logging
  MAX_CHANGE_IN_PERCENT = 0.15

  attr_reader :predicted_kwh_this_week, :predicted_kwh_last_week, :predicted_changein_kwh, :predicted_percent_increase_in_usage
  attr_reader :actual_kwh_this_week, :actual_kwh_last_week, :actual_changein_kwh, :actual_percent_increase_in_usage
  attr_reader :this_week_cost, :last_week_cost, :difference_in_actual_versus_predicted_change_percent
  attr_reader :predicted_this_week_cost, :predicted_last_week_cost, :predicted_change_in_cost
  attr_reader :signficant_increase_in_gas_consumption
  attr_reader :beginning_of_week, :beginning_of_last_week

  def initialize(school)
    super(school, :changeingasconsumption)
    @relevance = :never_relevant if @relevance != :never_relevant && non_heating_only
  end

  protected def max_days_out_of_date_while_still_relevant
    21
  end

  TEMPLATE_VARIABLES = {
    predicted_kwh_this_week: {
      description: 'kwh usage this week adjusted for temperature (school days only)',
      units:  {kwh: :gas}
    },
    predicted_kwh_last_week: {
      description: 'kwh usage last week adjusted for temperature  (school days only)',
      units:  {kwh: :gas}
    },
    predicted_changein_kwh: {
      description: 'change in kwh gas usage between this week and last week, adjusted for temperature, schools days only',
      units:  {kwh: :gas}
    },
    predicted_percent_increase_in_usage: {
      description: 'percentage change in kwh gas usage between this week and last week, adjusted for temperature, schools days only',
      units:  :percent
    },
    actual_kwh_this_week: {
      description: 'actual kwh usage this week  (school days only)',
      units:  {kwh: :gas}
    },
    actual_kwh_last_week: {
      description: 'actual kwh usage last week  (school days only)',
      units:  {kwh: :gas}
    },
    actual_changein_kwh: {
      description: 'change in actual kwh usage between this week and last week (school days only)',
      units:  {kwh: :gas}
    },
    actual_percent_increase_in_usage: {
      description: 'percent change in actual kwh usage between this week and last week (school days only)',
      units:  :percent
    },
    this_week_cost: {
      description: 'actual cost of school day gas consumption this week',
      units:  :£
    },
    last_week_cost: {
      description: 'actual cost of school day gas consumption last week',
      units:  :£
    },
    predicted_this_week_cost: {
      description: 'predicted cost of school day gas consumption this week (temperature compensated)',
      units:  :£
    },
    predicted_last_week_cost: {
      description: 'predicted cost of school day gas consumption last week (temperature compensated)',
      units:  :£
    },
    predicted_change_in_cost: {
      description: 'predicted cost of school day gas consumption last week (temperature compensated)',
      units:  :£
    },
    difference_in_actual_versus_predicted_change_percent: {
      description: 'percentage difference between actual and predicted changes between this week and last week',
      units:  :percent
    },
    signficant_increase_in_gas_consumption: {
      description: 'significant change in gas consumption between last 2 weeks (rating > 3, temperature adjusted)',
      units:  TrueClass
    },
    beginning_of_week: {
      description: 'Date of beginning of most recent assessment week',
      units: :date
    },
    beginning_of_last_week: {
      description: 'Date of beginning of previous assessment week',
      units: :date
    },
    last_2_weeks_gas_consumption_comparison_chart: {
      description: 'Temperature compensated last 2 weeks has consumption chart',
      units: :chart
    }
  }.freeze

  def last_2_weeks_gas_consumption_comparison_chart
    :alert_last_2_weeks_gas_comparison_temperature_compensated
  end

  def timescale
    'week (school days only)'
  end

  def enough_data
    days_amr_data > 3 * 7 && enough_data_for_model_fit ? :enough : :not_enough
  end

  def self.template_variables
    specific = {'Change In Gas Short Term' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def calculate(asof_date)
    calculate_model(asof_date)
    days_in_week = 5

    this_weeks_school_days = last_n_school_days(asof_date, days_in_week)
    last_weeks_school_days = last_n_school_days(this_weeks_school_days[0] - 1, days_in_week)

    @beginning_of_week = this_weeks_school_days[0]
    @beginning_of_last_week = last_weeks_school_days[0]

    @predicted_kwh_this_week = @heating_model.predicted_kwh_list_of_dates(this_weeks_school_days, @school.temperatures)
    @predicted_kwh_last_week = @heating_model.predicted_kwh_list_of_dates(last_weeks_school_days, @school.temperatures)
    @predicted_changein_kwh = @predicted_kwh_this_week - @predicted_kwh_last_week
    @predicted_percent_increase_in_usage = @predicted_changein_kwh / @predicted_kwh_last_week

    @predicted_this_week_cost = BenchmarkMetrics::GAS_PRICE * @predicted_kwh_this_week
    @predicted_last_week_cost = BenchmarkMetrics::GAS_PRICE * @predicted_kwh_last_week
    @predicted_change_in_cost = @predicted_this_week_cost - @predicted_last_week_cost

    @actual_kwh_this_week = @school.aggregated_heat_meters.amr_data.kwh_date_list(this_weeks_school_days)
    @actual_kwh_last_week = @school.aggregated_heat_meters.amr_data.kwh_date_list(last_weeks_school_days)
    @actual_changein_kwh = @actual_kwh_this_week - @actual_kwh_last_week
    @actual_percent_increase_in_usage = @actual_changein_kwh / @actual_kwh_last_week

    @this_week_cost = BenchmarkMetrics::GAS_PRICE * @actual_kwh_this_week
    @last_week_cost = BenchmarkMetrics::GAS_PRICE * @actual_kwh_last_week

    @difference_in_actual_versus_predicted_change_percent = @actual_percent_increase_in_usage - @predicted_percent_increase_in_usage

    heating_weeks = @heating_model.number_of_heating_days / days_in_week
    saving_£ = heating_weeks * (@predicted_this_week_cost - @predicted_last_week_cost)
    saving_£ = 0.0 if saving_£.nan?
    set_savings_capital_costs_payback(Range.new(saving_£, saving_£), nil)

    # PH, 16Aug2019 - as this alert is being deprecated, make more fault tolerant: St Louis school only
    @difference_in_actual_versus_predicted_change_percent = 0.0 if @difference_in_actual_versus_predicted_change_percent.nan?

    @rating = calculate_rating_from_range(0.2, -0.2, -1 * @difference_in_actual_versus_predicted_change_percent)

    @significant_increase_in_gas_consumption = @rating < 7.0

    @status = @signficant_increase_in_gas_consumption ? :bad : :good

    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('GasChange')
  end
  alias_method :analyse_private, :calculate
end
