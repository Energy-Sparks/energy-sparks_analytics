#======================== Change in Daily Electricity Consumption =============
require_relative 'alert_electricity_only_base.rb'

class AlertChangeInDailyElectricityShortTerm < AlertElectricityOnlyBase
  MAXDAILYCHANGE = 1.05

  attr_reader :last_weeks_consumption_kwh, :week_befores_consumption_kwh
  attr_reader :last_weeks_consumption_£, :week_befores_consumption_£
  attr_reader :signifcant_increase_in_electricity_consumption
  attr_reader :beginning_of_week, :beginning_of_last_week
  attr_reader :one_year_saving_£, :percent_change_in_consumption

  def initialize(school)
    super(school, :changeinelectricityconsumption)
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

  private def calculate(asof_date)
    # super(asof_date)
    days_in_week = 5

    @beginning_of_week, @last_weeks_consumption_kwh = schoolday_energy_usage_over_period(asof_date, days_in_week)
    @beginning_of_last_week, @week_befores_consumption_kwh = schoolday_energy_usage_over_period(@beginning_of_week - 1, days_in_week)

    @last_weeks_consumption_£ = @last_weeks_consumption_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    @week_befores_consumption_£ = @week_befores_consumption_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    @signifcant_increase_in_electricity_consumption = @last_weeks_consumption_kwh > @week_befores_consumption_kwh * MAXDAILYCHANGE

    @percent_change_in_consumption = ((@last_weeks_consumption_kwh - @week_befores_consumption_kwh) / @week_befores_consumption_kwh)

    saving_£ = 195.0 * (@last_weeks_consumption_£ - @week_befores_consumption_£) / days_in_week
    @one_year_saving_£ = Range.new(saving_£, saving_£)

    @rating = [10.0 - 10.0 * [@percent_change_in_consumption / 0.3, 0.0].max, 10.0].min.round(1)
    @status = @signifcant_increase_in_electricity_consumption ? :bad : :good
    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('ElectricityChange')
  end

  def default_content
    %{
      <% if signifcant_increase_in_electricity_consumption %>
        <p>
          Your electricity consumption on school days has increased from
          <%= week_befores_consumption_£ %> (<%= week_befores_consumption_kwh %>) last week (week starting <%= beginning_of_last_week %>) to
          <%= last_weeks_consumption_£ %> (<%= last_weeks_consumption_kwh %>) this week (week starting <%= beginning_of_week %>).
          If this continues it will cost you an additional <%= one_year_saving_£ %> over the next year.
        </p>
      <% else %>
        <p>
          Your electricity consumption on school days last week was
          <%= week_befores_consumption_£ %> (<%= week_befores_consumption_kwh %>) - (week starting <%= beginning_of_last_week %>).
          Your electricity consumption on school days this week is
          <%= last_weeks_consumption_£ %> (<%= last_weeks_consumption_kwh %>) - (week starting <%= beginning_of_week %>).
        </p>
      <% end %>
    }.gsub(/^  /, '')
  end

  def default_summary
    %{
      <% if signifcant_increase_in_electricity_consumption %>
        Your daily electricity consumption has increased.
      <% else %>
        Your daily electricity consumption is good
      <% end %>
    }.gsub(/^  /, '')
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    days_in_week = 5
    beginning_of_week, last_weeks_consumption = schoolday_energy_usage_over_period(asof_date, days_in_week)
    beginning_of_last_week, week_befores_consumption = schoolday_energy_usage_over_period(beginning_of_week - 1, days_in_week)

    @analysis_report.term = :shortterm
    @analysis_report.add_book_mark_to_base_url('ElectricityChange')

    if last_weeks_consumption > week_befores_consumption * MAXDAILYCHANGE
      last_weeks_baseload = average_baseload_kw(asof_date - 7, asof_date)
      @analysis_report.summary = 'Your daily electricity consumption has increased'
      text = sprintf('Your electricity consumption has increased from %.0f kWh ', week_befores_consumption)
      text += sprintf('last week (5 school days following %s) ', beginning_of_last_week.to_formatted_s(:long_ordinal))
      text += sprintf('to %.0f kWh ', last_weeks_consumption)
      text += sprintf('this week (5 school days following %s) ', beginning_of_week.to_formatted_s(:long_ordinal))
      text += sprintf('over the last year to %.1f last week. ', last_weeks_baseload)
      cost = BenchmarkMetrics::ELECTRICITY_PRICE * 195.0 * (last_weeks_consumption - week_befores_consumption) / days_in_week
      text += sprintf('If this continues it will costs you an additional £%.0f over the next year.', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your daily electricity consumption is good'
      text = sprintf('Your weekly school day electricity consumption was %.0f kWh (£%.0f) this week ',
                     last_weeks_consumption,
                     last_weeks_consumption * BenchmarkMetrics::ELECTRICITY_PRICE)
      text += sprintf('compared with %.0f kWh (£%.0f) last week.',
                      week_befores_consumption,
                      week_befores_consumption * BenchmarkMetrics::ELECTRICITY_PRICE)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end

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