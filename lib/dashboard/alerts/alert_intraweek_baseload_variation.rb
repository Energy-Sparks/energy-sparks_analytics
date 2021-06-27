#======================== Change in Electricity Baseload Analysis =============
require_relative 'alert_electricity_only_base.rb'

class AlertIntraweekBaseloadVariation < AlertBaseloadBase
  attr_reader :max_day_kw, :min_day_kw, :percent_intraday_variation
  attr_reader :max_day_str, :min_day_str
  attr_reader :annual_cost_kwh, :annual_cost_£
  attr_reader :one_year_baseload_chart

  def initialize(school)
    super(school, :seasonalbaseload)
  end

  TEMPLATE_VARIABLES = {
    max_day_kw: {
      description: 'max average day baseload kw',
      units:  :kw,
      benchmark_code: 'mxbk'
    },
    max_day_str: {
      description: 'Day of week name with max average baseload',
      units:  String,
      benchmark_code: 'mxbd'
    },
    min_day_kw: {
      description: 'min average day baseload kw',
      units:  :kw,
      benchmark_code: 'mnbk'
    },
    min_day_str: {
      description: 'Day of week name with min average baseload',
      units:  String,
      benchmark_code: 'mnbd'
    },
    percent_intraday_variation: {
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

    days_kw = calculator.average_intraweek_schoolday_kw(asof_date)

    day_strs = %w[ sunday monday tuesday wednesday thursday friday saturday ]

    @min_day_kw = days_kw.values.min
    min_day = days_kw.key(@min_day_kw)
    @min_day_str = day_strs[min_day]

    @max_day_kw = days_kw.values.max
    max_day = days_kw.key(@max_day_kw)
    @max_day_str = day_strs[max_day]

    @percent_intraday_variation = (@max_day_kw - @min_day_kw) / @min_day_kw

    week_saving_kwh = days_kw.values.map do |day_kw|
      (@max_day_kw - day_kw) * 24.0
    end.sum

    @annual_cost_kwh = week_saving_kwh * 52.0 # ignore holiday calc
    @annual_cost_£ = @annual_cost_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    set_savings_capital_costs_payback(Range.new(@annual_cost_£, @annual_cost_£), nil)

    @rating = calculate_rating_from_range(0.1, 0.3, @percent_intraday_variation.magnitude)

    @term = :longterm
  end
  alias_method :analyse_private, :calculate
end
