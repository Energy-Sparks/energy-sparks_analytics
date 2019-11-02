#==============================================================================
#==============================================================================
#========================HEATING/GAS===========================================
#==============================================================================
#==============================================================================
#==============================================================================
#======================== Gas Annual kWh Versus Benchmark =====================
# currently not derived from a common base class with electricity as we may need
# to tmperature adjust in future
require_relative 'alert_gas_only_base.rb'

class AlertGasAnnualVersusBenchmark < AlertGasOnlyBase
  attr_reader :last_year_kwh, :last_year_£

  attr_reader :one_year_benchmark_floor_area_kwh, :one_year_benchmark_floor_area_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_floor_area_kwh, :one_year_exemplar_floor_area_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_gas_per_pupil_kwh, :one_year_gas_per_pupil_£
  attr_reader :one_year_gas_per_floor_area_kwh, :one_year_gas_per_floor_area_£

  def initialize(school, type = :annualgasbenchmark)
    super(school, type)
  end

  def self.template_variables
    specific = {'Annual gas usage versus benchmark' => gas_benchmark_template_variables}
    specific.merge(self.superclass.template_variables)
  end
  
  def self.gas_benchmark_template_variables
    {
      last_year_kwh: {
        description: "Last years gas consumption - kwh",
        units:  {kwh: :gas}
      },
      last_year_£: {
        description: 'Last years gas consumption - £ including differential tariff',
        units:  {£: :gas},
        benchmark_code: '£lyr'
      },
      one_year_benchmark_floor_area_kwh: {
        description: 'Last years gas consumption for benchmark/average school, normalised by floor area - kwh',
        units:  {kwh: :gas}
      },
      one_year_benchmark_floor_area_£: {
        description: 'Last years gas consumption for benchmark/average school, normalised by floor area - £',
        units:  {£: :gas}
      },
      one_year_saving_versus_benchmark_kwh: {
        description: 'Annual difference in gas consumption versus benchmark/average school - kwh (use adjective for sign)',
        units:  {kwh: :gas}
      },
      one_year_saving_versus_benchmark_£: {
        description: 'Annual difference in gas consumption versus benchmark/average school - £ (use adjective for sign)',
        units:  {£: :gas}
      },
      one_year_saving_versus_benchmark_adjective: {
        description: 'Adjective: higher or lower: gas consumption versus benchmark/average school',
        units:  String
      },

      one_year_exemplar_floor_area_kwh: {
        description: 'Last years gas consumption for exemplar school, normalised by floor area - kwh',
        units:  {kwh: :gas}
      },
      one_year_exemplar_floor_area_£: {
        description: 'Last years gas consumption for exemplar school, normalised by floor area - £',
        units:  {£: :gas},
        benchmark_code: '£exa'
      },
      one_year_saving_versus_exemplar_kwh: {
        description: 'Annual difference in gas consumption versus exemplar school - kwh (use adjective for sign)',
        units:  {kwh: :gas}
      },
      one_year_saving_versus_exemplar_£: {
        description: 'Annual difference in gas consumption versus exemplar school - £ (use adjective for sign)',
        units:  {£: :gas}
      },
      one_year_saving_versus_exemplar_adjective: {
        description: 'Adjective: higher or lower: gas consumption versus exemplar school',
        units:  String
      },

      one_year_gas_per_pupil_kwh: {
        description: 'Per pupil annual gas usage - kwh - required for PH analysis, not alerts',
        units:  {kwh: :gas}
      },
      one_year_gas_per_pupil_£: {
        description: 'Per pupil annual gas usage - £ - required for PH analysis, not alerts',
        units:  {£: :gas}
      },
      one_year_gas_per_floor_area_kwh: {
        description: 'Per floor area annual gas usage - kwh - required for PH analysis, not alerts',
        units:  {kwh: :gas}
      },
      one_year_gas_per_floor_area_£: {
        description: 'Per floor area annual gas usage - £ - required for PH analysis, not alerts',
        units:  {£: :gas},
        benchmark_code: 'pfla'
      }
    }
  end

  def timescale
    'last year'
  end

  def enough_data
    days_amr_data >= 364 ? :enough : :not_enough
  end

  private def calculate(asof_date)
    raise EnergySparksNotEnoughDataException, "Not enough data: 1 year of data required, got #{days_amr_data} days" if enough_data == :not_enough
    @last_year_kwh = kwh(asof_date - 365, asof_date, :kwh)
    @last_year_£   = kwh(asof_date - 365, asof_date, :economic_cost)

    @one_year_benchmark_floor_area_kwh   = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * floor_area
    @one_year_benchmark_floor_area_£     = @one_year_benchmark_floor_area_kwh * fuel_price

    @one_year_saving_versus_benchmark_kwh = @last_year_kwh - @one_year_benchmark_floor_area_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * fuel_price
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh.magnitude
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£.magnitude

    @one_year_exemplar_floor_area_kwh   = BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * floor_area
    @one_year_exemplar_floor_area_£     = @one_year_exemplar_floor_area_kwh * fuel_price

    @one_year_saving_versus_exemplar_kwh = @last_year_kwh - @one_year_exemplar_floor_area_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * fuel_price
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh.magnitude
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£.magnitude

    @one_year_gas_per_pupil_kwh       = @last_year_kwh / pupils
    @one_year_gas_per_pupil_£         = @last_year_£ / pupils
    @one_year_gas_per_floor_area_kwh  = @last_year_kwh / floor_area
    @one_year_gas_per_floor_area_£    = @last_year_£ / floor_area

    set_savings_capital_costs_payback(Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£), nil)

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@last_year_kwh - @one_year_benchmark_floor_area_kwh) / (@one_year_exemplar_floor_area_kwh - @one_year_benchmark_floor_area_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('AnnualGas')
  end
  alias_method :analyse_private, :calculate
end
