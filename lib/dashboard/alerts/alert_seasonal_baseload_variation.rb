#======================== Change in Electricity Baseload Analysis =============
require_relative 'alert_electricity_only_base.rb'

class AlertSeasonalBaseloadVariation < AlertBaseloadBase
  attr_reader :winter_kw, :summer_kw, :percent_seasonal_variation
  attr_reader :annual_cost_kwh, :annual_cost_£
  attr_reader :one_year_baseload_chart

  def initialize(school)
    super(school, :seasonalbaseload)
  end

  TEMPLATE_VARIABLES = {
    winter_kw: {
      description: 'winter baseload kw',
      units:  :kw,
      benchmark_code: 'wtbl'
    },
    summer_kw: {
      description: 'summer baseload kw',
      units:  :kw,
      benchmark_code: 'smbl'
    },
    percent_seasonal_variation: {
      description: 'seasonal baseload variation percent (relative)',
      units:  :relative_percent,
      benchmark_code: 'sblp'
    },
    annual_cost_kwh: {
      description: 'annual cost of seasonal baseload variation (kWh)',
      units:  :kwh,
      benchmark_code: 'ckwh'
    },
    annual_cost_£: {
      description: 'annual cost of seasonal baseload variation (£)',
      units:  :£,
      benchmark_code: 'cgbp'
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

  def enough_data
    calculator.one_years_data? ? :enough : :not_enough
  end

  def timescale
    'over the last year'
  end

  private

  def calculator
    @calculator ||= ElectricityBaseloadAnalysis.new(@meter)
  end

  def calculate(asof_date)
    # def 'enough_data' doesn;t know the asof_date
    raise EnergySparksNotEnoughDataException, "Needs 1 years amr data for as of date #{asof_date}" unless calculator.one_years_data?(asof_date)
    
    @winter_kw = calculator.winter_kw(asof_date)
    @summer_kw = calculator.summer_kw(asof_date)
    @percent_seasonal_variation = calculator.percent_seasonal_variation(asof_date)

    @annual_cost_kwh = calculator.costs_of_baseload_above_minimum_kwh(asof_date, @summer_kw)
    @annual_cost_£ = @annual_cost_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    set_savings_capital_costs_payback(Range.new(@annual_cost_£ , @annual_cost_£ ), nil)

    @rating = calculate_rating_from_range(0, 0.50, @percent_seasonal_variation.magnitude)

    @term = :longterm
  end
  alias_method :analyse_private, :calculate
end
