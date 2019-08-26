#======================== Weekend Gas Consumption =============================
# gas shouldn't be consumed at weekends, apart for from frost protection
require_relative 'alert_gas_model_base.rb'

class AlertWeekendGasConsumptionShortTerm < AlertGasModelBase
  MAX_COST = 5.0 # £5 limit
  FROST_PROTECTION_TEMPERATURE = 4

  attr_reader :last_week_end_kwh, :last_weekend_cost_£
  attr_reader :last_year_weekend_gas_kwh, :last_year_weekend_gas_£
  attr_reader :average_weekend_gas_kwh, :average_weekend_gas_£
  attr_reader :percent_increase_on_average_weekend, :projected_percent_of_annual

  def initialize(school)
    super(school, :weekendgasconsumption)
  end

  def timescale
    'last weekend'
  end

  def enough_data
    days_amr_data >= 7 ? :enough : :not_enough
  end

  def self.template_variables
    specific = {'Weekend gas consumption' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    last_week_end_kwh: {
      description: 'Gas consumption last weekend kWh (above frost)',
      units: { kwh: :gas }
    },
    last_weekend_cost_£: {
      description: 'Gas consumption last weekend £ (above frost)',
      units: :£
    },
    last_year_weekend_gas_kwh: {
      description: 'Gas consumption last year kWh (scaled up to a year if not enough data)',
      units: { kwh: :gas }
    },
    last_year_weekend_gas_£: {
      description: 'Gas consumption last year £ (scaled up to a year if not enough data)',
      units: :£
    },
    average_weekend_gas_kwh: {
      description: 'Average weekend gas consumption last year kWh (scaled up to a year if not enough data)',
      units: { kwh: :gas }
    },
    average_weekend_gas_£: {
      description: 'Average weekend gas consumption last year £ (scaled up to a year if not enough data)',
      units: :£
    },
    percent_increase_on_average_weekend: {
      description: 'Percent increase on average weekend over last year',
      units: :percent
    },
    projected_percent_of_annual: {
      description: 'Last weekends (projected i.e. x 52) consumption as a percent of total annual gas consumption',
      units: :percent
    },
    last_7_day_intraday_kwh_chart: {
      description: 'last 7 days gas consumption chart (intraday) - suggest zoom to user, kWh per half hour',
      units: :chart
    },
    last_7_day_intraday_kw_chart: {
      description: 'last 7 days gas consumption chart (intraday) - suggest zoom to user, kW per half hour',
      units: :chart
    },
    last_7_day_intraday_£_chart: {
      description: 'last 7 days gas consumption chart (intraday) - suggest zoom to user, £ per half hour',
      units: :chart
    }
  }.freeze

  def last_7_day_intraday_kwh_chart
    :alert_weekend_last_week_gas_datetime_kwh
  end

  def last_7_day_intraday_kw_chart
    :alert_weekend_last_week_gas_datetime_kw
  end

  def last_7_day_intraday_£_chart
    :alert_weekend_last_week_gas_datetime_£
  end

  private def calculate(asof_date)
    calculate_model(asof_date)
    @weekend_dates = previous_weekend_dates(asof_date)
    @last_week_end_kwh = kwh_usage_outside_frost_period(@weekend_dates, FROST_PROTECTION_TEMPERATURE)
    @last_weekend_cost_£ = gas_cost(@last_week_end_kwh)
    @last_year_weekend_gas_kwh = weekend_gas_consumption_last_year(asof_date)
    @last_year_weekend_gas_£ = gas_cost(@last_year_weekend_gas_kwh)

    @average_weekend_gas_kwh = @last_year_weekend_gas_kwh / 52
    @average_weekend_gas_£   = @last_year_weekend_gas_£ / 52

    @percent_increase_on_average_weekend = @average_weekend_gas_kwh == 0.0 ? 0.0 : (@last_week_end_kwh - @average_weekend_gas_kwh) / @average_weekend_gas_kwh
    @projected_percent_of_annual = @last_week_end_kwh * 52.0 / annual_kwh(aggregate_meter, asof_date)

    increase_rating  = calculate_rating_from_range(0.0, 0.20, @percent_increase_on_average_weekend)
    of_annual_rating = calculate_rating_from_range(0.02, 0.12, @projected_percent_of_annual)
    combined_rating = increase_rating * of_annual_rating / 10.0

    set_savings_capital_costs_payback(52.0 * (@last_weekend_cost_£ - @average_weekend_gas_£), 0.0)

    @rating = @last_weekend_cost_£ < MAX_COST ? 10.0 : combined_rating

    puts "increase on annual #{(@percent_increase_on_average_weekend * 100.0).round(1)} projected percent of annual #{(@projected_percent_of_annual * 100.0).round(1)} rating #{@rating.round(2)} cost #{@average_one_year_saving_£.round(0)}"

    @status = @rating < 5.0 ? :bad : :good

    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('WeekendGas')
  end
  alias_method :analyse_private, :calculate

  private def previous_weekend_dates(asof_date)
    weekend_dates = []
    while weekend_dates.length < 2
      weekend_dates.push(asof_date) if weekend?(asof_date)
      asof_date -= 1
    end
    weekend_dates.sort
  end

  private def weekend_gas_consumption_last_year(asof_date)
    start_date = meter_date_one_year_before(aggregate_meter, asof_date)
    annual_kwh = 0.0
    (start_date..asof_date).each do |date|
      annual_kwh += aggregate_meter.amr_data.one_day_kwh(date) if weekend?(date)
    end
    annual_kwh * scale_up_to_one_year(aggregate_meter, asof_date)
  end

  private def kwh_usage_outside_frost_period(dates, frost_protection_temperature)
    total_kwh = 0.0
    dates.each do |date|
      (0..47).each do |halfhour_index|
        if @school.temperatures.temperature(date, halfhour_index) > frost_protection_temperature
          total_kwh += @school.aggregated_heat_meters.amr_data.kwh(date, halfhour_index)
        end
      end
    end
    total_kwh
  end
end
