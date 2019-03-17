#======================== Change in Electricity Baseload Analysis =============
require_relative 'alert_electricity_only_base.rb'

class AlertChangeInElectricityBaseloadShortTerm < AlertElectricityOnlyBase
  MAXBASELOADCHANGE = 1.15

  attr_reader :average_baseload_last_year_kw, :average_baseload_last_week_kw
  attr_reader :change_in_baseload_kw, :kw_value_at_10_percent_saving
  attr_reader :last_year_baseload_kwh, :last_week_baseload_kwh
  attr_reader :last_week_change_in_baseload_kwh, :next_year_change_in_baseload_kwh
  attr_reader :last_year_baseload_£, :last_week_baseload_£, :next_year_change_in_baseload_£
  attr_reader :one_year_saving_£, :saving_in_annual_costs_through_10_percent_baseload_reduction
  attr_reader :predicted_percent_increase_in_usage, :significant_increase_in_baseload
  attr_reader :one_year_baseload_chart

  def initialize(school)
    super(school, :baseloadchangeshortterm)
  end

  TEMPLATE_VARIABLES = {
    average_baseload_last_year_kw: {
      description: 'average baseload over last year',
      units:  :kw
    },
    average_baseload_last_week_kw: {
      description: 'average baseload over last week',
      units:  :kw
    },
    change_in_baseload_kw: {
      description: 'change in baseload last week compared with the average over the last year',
      units:  :kw
    },
    last_year_baseload_kwh: {
      description: 'baseload last year (kwh)',
      units:  {kwh: :electricity}
    },
    last_week_baseload_kwh: {
      description: 'baseload last week (kwh)',
      units:  {kwh: :electricity}
    },
    last_week_change_in_baseload_kwh: {
      description: 'change in baseload last week (kwh)',
      units:  {kwh: :electricity}
    },
    next_year_change_in_baseload_kwh: {
      description: 'predicted change in baseload over next year (kwh)',
      units:  {kwh: :electricity}
    },
    last_year_baseload_£: {
      description: 'cost of the baseload electricity consumption last year',
      units:  :£
    },
    last_week_baseload_£: {
      description: 'cost of the baseload electricity consumption last week',
      units:  :£
    },
    next_year_change_in_baseload_£: {
      description: 'projected addition cost of change in baseload next year',
      units:  :£
    },
    predicted_percent_increase_in_usage: {
      description: 'percentage increase in baseload',
      units:  :percent
    },
    significant_increase_in_baseload: {
      description: 'significant increase in baseload flag',
      units:  TrueClass
    },
    saving_in_annual_costs_through_10_percent_baseload_reduction:  {
      description: 'cost saving if baseload reduced by 10%',
      units:  :£
    },
    kw_value_at_10_percent_saving:  {
      description: 'kw at 10 percent reduction on last years average baseload',
      units:  :kw
    },
    one_year_baseload_chart: {
      description: 'chart of last years baseload',
      units: :chart
    }
  }.freeze

  def one_year_baseload_chart
    :alert_1_year_baseload
  end

  def self.template_variables
    specific = {'Change In Baseload Short Term' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def calculate(asof_date)
    @average_baseload_last_year_kw, _days_sample = baseload(asof_date)
    @kw_value_at_10_percent_saving = @average_baseload_last_year_kw * 0.9
    @average_baseload_last_week_kw = average_baseload(asof_date - 7, asof_date)
    @change_in_baseload_kw = @average_baseload_last_week_kw - @average_baseload_last_year_kw
    @predicted_percent_increase_in_usage = (@average_baseload_last_week_kw - @average_baseload_last_year_kw) / @average_baseload_last_year_kw

    hours_in_year = 365.0 * 24.0
    hours_in_week =   7.0 * 24.0

    @last_year_baseload_kwh = @average_baseload_last_week_kw * hours_in_year
    @last_week_baseload_kwh = @average_baseload_last_week_kw * hours_in_week
    @last_week_change_in_baseload_kwh = @change_in_baseload_kw * hours_in_week
    @next_year_change_in_baseload_kwh = @change_in_baseload_kw * hours_in_year

    @last_year_baseload_£ = BenchmarkMetrics::ELECTRICITY_PRICE * @last_year_baseload_kwh
    @last_week_baseload_£ = BenchmarkMetrics::ELECTRICITY_PRICE * @last_week_baseload_kwh
    @next_year_change_in_baseload_£ = BenchmarkMetrics::ELECTRICITY_PRICE * @next_year_change_in_baseload_kwh
    @saving_in_annual_costs_through_10_percent_baseload_reduction = @last_year_baseload_£ * 0.1

    @one_year_saving_£ = Range.new(@next_year_change_in_baseload_£, @next_year_change_in_baseload_£)

    @rating = [10.0 - 10.0 * [@predicted_percent_increase_in_usage / 0.3, 0.0].max, 10.0].min.round(1)

    @significant_increase_in_baseload = @rating < 7.0

    @status = @significant_increase_in_baseload ? :bad : :good

    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('ElectricityBaseload')
  end

  def default_content
    %{
      <p>
        <% if significant_increase_in_baseload %>
          Your electricity baseload has increased.
        <% else %>
          Your electricity baseload is good.
        <% end %>
      </p>
      <p>
        Your electricity baseload  was <%= average_baseload_last_week_kw %> this week
        compared with an average of <%= average_baseload_last_year_kw %> over the last year.
      </p>
      <% if significant_increase_in_baseload %>
        <p>
          If this continues it will costs you an additional <%= one_year_saving_£ %> over the next year.
        </p>
      <% else %>
        <p>
          However, if you reduced you baseload by 10 percent from <%= average_baseload_last_year_kw %>
          to <%= kw_value_at_10_percent_saving %> by turning appliances off
          which have been left on overnight, during weekends and holidays you would save
          <%= saving_in_annual_costs_through_10_percent_baseload_reduction %> each year.
        </p>
      <% end %>
      </end>
    }.gsub(/^  /, '')
  end

  def default_summary
    %{
      <p>
        <% if significant_increase_in_baseload %>
          Your electricity baseload has increased.
        <% else %>
          Your electricity baseload is good.
        <% end %>
      </p>
    }.gsub(/^  /, '')
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    @average_baseload_last_year_kw, days_sample = baseload(asof_date)
    @average_baseload_last_week_kw = average_baseload(asof_date - 7, asof_date)

    @analysis_report.term = :shortterm
    @analysis_report.add_book_mark_to_base_url('ElectricityBaseload')

    if @average_baseload_last_week_kw > @average_baseload_last_year_kw * MAXBASELOADCHANGE
      @analysis_report.summary = 'Your electricity baseload has increased'
      text = sprintf('Your electricity baseload has increased from %.1f kW ', @average_baseload_last_year_kw)
      text += sprintf('over the last year to %.1f kW last week. ', @average_baseload_last_week_kw)
      cost = BenchmarkMetrics::ELECTRICITY_PRICE * 365.0 * 24 * (@average_baseload_last_week_kw - @average_baseload_last_year_kw)
      text += sprintf('If this continues it will costs you an additional £%.0f over the next year.', cost)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your electricity baseload is good'
      text = sprintf('Your baseload electricity was %.2f kW this week ', @average_baseload_last_week_kw)
      text += sprintf('compared with an average of %.2f kW over the last year.', @average_baseload_last_year_kw)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end
end