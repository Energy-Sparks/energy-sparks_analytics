#======================== Change in Daily Electricity Consumption =============
require_relative 'alert_electricity_only_base.rb'

class AlertChangeInDailyElectricityShortTerm < AlertElectricityOnlyBase
  MAXDAILYCHANGE = 1.05

  attr_reader :last_weeks_consumption_kwh, :week_befores_consumption_kwh
  attr_reader :last_weeks_consumption_£, :week_befores_consumption_£
  attr_reader :last_weeks_consumption_co2, :week_befores_consumption_co2
  attr_reader :signifcant_increase_in_electricity_consumption
  attr_reader :beginning_of_week, :beginning_of_last_week
  attr_reader :percent_change_in_consumption

  def initialize(school)
    super(school, :changeinelectricityconsumption)
  end

  protected def max_days_out_of_date_while_still_relevant
    21
  end

  def self.template_variables
    specific = {'Change in electricity short term' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    last_weeks_consumption_kwh: {
      description: 'Last weeks electricity consumption on school days - kwh',
      units:  {kwh: :electricity}
    },
    week_befores_consumption_kwh: {
      description: 'The week befores electricity consumption on school days - kwh',
      units:  {kwh: :electricity}
    },
    last_weeks_consumption_£: {
      description: 'Last weeks electricity consumption on school days - £',
      units:  :£
    },
    week_befores_consumption_£: {
      description: 'The week befores electricity consumption on school days - £',
      units:  :£,
    },
    last_weeks_consumption_co2: {
      description: 'Last weeks electricity consumption on school days - co2',
      units:  :co2
    },
    week_befores_consumption_co2: {
      description: 'The week befores electricity consumption on school days - co2',
      units:  :co2,
    },
    signifcant_increase_in_electricity_consumption: {
      description: 'More than 5% increase in weekly electricity consumption in last 2 weeks',
      units:  TrueClass
    },
    percent_change_in_consumption: {
      description: 'Percent change in electricity consumption between last 2 weeks',
      units:  :percent
    },
    beginning_of_week: {
      description: 'Date of beginning of most recent assessment week',
      units: :date
    },
    beginning_of_last_week: {
      description: 'Date of beginning of previous assessment week',
      units: :date
    },
    week_on_week_electricity_daily_electricity_comparison_chart: {
      description: 'Week on week daily electricity comparison chart column chart',
      units: :chart
    },
    last_5_weeks_intraday_school_day_chart: {
      description: 'Average kW intraday for last 5 weeks line chart',
      units: :chart
    },
    last_7_days_intraday_chart: {
      description: 'Last 7 days intraday chart line chart',
      units: :chart
    },
  }.freeze

  def week_on_week_electricity_daily_electricity_comparison_chart
    :alert_week_on_week_electricity_daily_electricity_comparison_chart
  end

  def last_5_weeks_intraday_school_day_chart
    :alert_intraday_line_school_days_last5weeks
  end

  def last_7_days_intraday_chart
    :alert_intraday_line_school_last7days
  end

  def timescale
    'week (school days only)'
  end

  def enough_data
    days_amr_data > 3 * 7 ? :enough : :not_enough
  end

  private def calculate(asof_date)
    # super(asof_date)
    days_in_week = 5

    @beginning_of_week, @last_weeks_consumption_kwh = schoolday_energy_usage_over_period(asof_date, days_in_week)
    # -1 moves the the date to the previous N school day period
    @beginning_of_last_week, @week_befores_consumption_kwh = schoolday_energy_usage_over_period(@beginning_of_week - 1, days_in_week)

    @last_weeks_consumption_£ = @last_weeks_consumption_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    @week_befores_consumption_£ = @week_befores_consumption_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    @last_weeks_consumption_co2   = @last_weeks_consumption_kwh   * blended_co2_per_kwh
    @week_befores_consumption_co2 = @week_befores_consumption_kwh * blended_co2_per_kwh

    @signifcant_increase_in_electricity_consumption = @last_weeks_consumption_kwh > @week_befores_consumption_kwh * MAXDAILYCHANGE

    @percent_change_in_consumption = ((@last_weeks_consumption_kwh - @week_befores_consumption_kwh) / @week_befores_consumption_kwh)

    saving_£    = 195.0 * (@last_weeks_consumption_£   - @week_befores_consumption_£)   / days_in_week
    saving_co2  = 195.0 * (@last_weeks_consumption_co2 - @week_befores_consumption_co2) / days_in_week
    set_savings_capital_costs_payback(Range.new(saving_£, saving_£), nil, saving_co2)

    @rating = calculate_rating_from_range(-0.05, 0.15, @percent_change_in_consumption)
    @status = @signifcant_increase_in_electricity_consumption ? :bad : :good
    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('ElectricityChange')
  end
  alias_method :analyse_private, :calculate

  private def schoolday_energy_usage_over_period(asof_date, school_days)
    list_of_school_days = last_n_school_days(asof_date, school_days)
    total_kwh = 0.0
    list_of_school_days.each do |date|
      total_kwh += days_energy_consumption(date)
    end
    [list_of_school_days[0], total_kwh]
  end

  private def days_energy_consumption(date)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.one_day_kwh(date)
  end
end