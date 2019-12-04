#==============================================================================
#==============================================================================
#========================HEATING/GAS===========================================
#==============================================================================
#==============================================================================
#==============================================================================
#======================== Gas Annual kWh Versus Benchmark =====================
# currently not derived from a common base class with electricity as we may need
# to tmperature adjust in future
# storage heaters derived from this class, most of code shared - beware
require_relative 'alert_gas_only_base.rb'

class AlertGasAnnualVersusBenchmark < AlertGasOnlyBase
  attr_reader :last_year_kwh, :last_year_£, :last_year_co2

  attr_reader :one_year_benchmark_floor_area_kwh, :one_year_benchmark_floor_area_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_floor_area_kwh, :one_year_exemplar_floor_area_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_gas_per_pupil_kwh, :one_year_gas_per_pupil_£
  attr_reader :one_year_gas_per_floor_area_kwh, :one_year_gas_per_floor_area_£
  attr_reader :one_year_gas_per_pupil_co2, :one_year_gas_per_floor_area_co2

  attr_reader :degree_day_adjustment

  attr_reader :one_year_gas_per_pupil_normalised_kwh, :one_year_gas_per_pupil_normalised_£
  attr_reader :one_year_gas_per_floor_area_normalised_kwh, :one_year_gas_per_floor_area_normalised_£

  attr_reader :per_floor_area_gas_benchmark_£
  attr_reader :percent_difference_from_average_per_floor_area, :percent_difference_adjective
  attr_reader :simple_percent_difference_adjective, :summary

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
        units:  {kwh: :gas},
        benchmark_code: 'klyr'
      },
      last_year_£: {
        description: 'Last years gas consumption - £ including differential tariff',
        units:  {£: :gas},
        benchmark_code: '£lyr'
      },
      last_year_co2: {
        description: 'Last years gas CO2 kg',
        units:  :co2,
        benchmark_code: 'co2y'
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
        units:  {£: :gas},
        benchmark_code: 's£ex'
      },
      one_year_saving_versus_exemplar_adjective: {
        description: 'Adjective: higher or lower: gas consumption versus exemplar school',
        units:  String
      },

      one_year_gas_per_pupil_kwh: {
        description: 'Per pupil annual gas usage - kwh - required for PH analysis, not alerts',
        units:  {kwh: :gas},
        benchmark_code: 'kpup'
      },
      one_year_gas_per_pupil_£: {
        description: 'Per pupil annual gas usage - £ - required for PH analysis, not alerts',
        units:  {£: :gas},
        benchmark_code: '£pup'
      },
      one_year_gas_per_pupil_co2: {
        description: 'Per pupil annual gas usage - co2 - required for PH analysis, not alerts',
        units:  :co2,
        benchmark_code: 'cpup'
      },
      one_year_gas_per_floor_area_co2: {
        description: 'Per floor area annual gas usage - co2 - required for PH analysis, not alerts',
        units:  :co2,
        benchmark_code: 'cfla'
      },
      one_year_gas_per_floor_area_kwh: {
        description: 'Per floor area annual gas usage - kwh - required for PH analysis, not alerts',
        units:  {kwh: :gas}
      },
      one_year_gas_per_floor_area_£: {
        description: 'Per floor area annual gas usage - £ - required for PH analysis, not alerts',
        units:  {£: :gas},
        benchmark_code: 'pfla'
      },
      degree_day_adjustment: {
        description: 'Regional degree day adjustment; 60% of adjustment for Gas (not 100% heating consumption), 100% of Storage Heaters',
        units: Float,
        benchmark_code: 'ddaj'
      },
      one_year_gas_per_pupil_normalised_kwh: {
        description: 'Per pupil annual gas usage - kwh - temperature normalised (internal use only)',
        units:  {kwh: :gas},
        benchmark_code: 'nkpp'
      },
      one_year_gas_per_pupil_normalised_£: {
        description: 'Per pupil annual gas usage - £ - temperature normalised (internal use only)',
        units:  {£: :gas},
        benchmark_code: 'n£pp'
      },
      one_year_gas_per_floor_area_normalised_kwh: {
        description: 'Per floor area annual gas usage - kwh - temperature normalised (internal use only)',
        units:  {kwh: :gas},
        benchmark_code: 'nkm2'
      },
      one_year_gas_per_floor_area_normalised_£: {
        description: 'Per floor area annual gas usage - £ - temperature normalised (internal use only)',
        units:  {£: :gas},
        benchmark_code: 'n£m2'
      },
      per_floor_area_gas_benchmark_£: {
        description: 'Per floor area annual gas usage - £',
        units:  {£: :gas}
      },
      percent_difference_from_average_per_floor_area: {
        description: 'Percent difference from average',
        units:  :relative_percent,
        benchmark_code: 'pp%d'
      },
      percent_difference_adjective: {
        description: 'Adjective relative to average: above, signifantly above, about',
        units: String
      },
      simple_percent_difference_adjective:  {
        description: 'Adjective relative to average: above, about, below',
        units: String
      },
      summary: {
        description: 'Description: £spend, adj relative to average',
        units: String
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
    @degree_day_adjustment = dd_adj(asof_date)

    @last_year_kwh = kwh(asof_date - 365, asof_date, :kwh)
    @last_year_£   = kwh(asof_date - 365, asof_date, :economic_cost)
    @last_year_co2 = kwh(asof_date - 365, asof_date, :co2)

    @one_year_benchmark_floor_area_kwh   = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * floor_area / @degree_day_adjustment
    @one_year_benchmark_floor_area_£     = @one_year_benchmark_floor_area_kwh * fuel_price

    @one_year_saving_versus_benchmark_kwh = @last_year_kwh - @one_year_benchmark_floor_area_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * fuel_price
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£

    @one_year_exemplar_floor_area_kwh   = BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * floor_area / @degree_day_adjustment
    @one_year_exemplar_floor_area_£     = @one_year_exemplar_floor_area_kwh * fuel_price

    @one_year_saving_versus_exemplar_kwh = @last_year_kwh - @one_year_exemplar_floor_area_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * fuel_price
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£

    @one_year_gas_per_pupil_kwh       = @last_year_kwh / pupils
    @one_year_gas_per_pupil_£         = @last_year_£ / pupils
    @one_year_gas_per_floor_area_kwh  = @last_year_kwh / floor_area
    @one_year_gas_per_floor_area_£    = @last_year_£ / floor_area

    @one_year_gas_per_pupil_co2       = @last_year_co2  / pupils
    @one_year_gas_per_floor_area_co2  = @last_year_co2  / floor_area

    @one_year_gas_per_pupil_normalised_kwh        = @one_year_gas_per_pupil_kwh * @degree_day_adjustment
    @one_year_gas_per_pupil_normalised_£          = @one_year_gas_per_pupil_£ * @degree_day_adjustment
    @one_year_gas_per_floor_area_normalised_kwh   = @one_year_gas_per_floor_area_kwh * @degree_day_adjustment
    @one_year_gas_per_floor_area_normalised_£     = @one_year_gas_per_floor_area_£ * @degree_day_adjustment

    @per_floor_area_gas_£ = @last_year_£ / @school.floor_area
    @per_floor_area_gas_benchmark_£ = @one_year_benchmark_floor_area_£ / @school.floor_area
    @percent_difference_from_average_per_floor_area = percent_change(@per_floor_area_gas_benchmark_£, one_year_gas_per_floor_area_£)
    @percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_floor_area, :relative_to_1)
    @simple_percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_floor_area, :simple_relative_to_1)

    @summary = summary_text

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

  def summary_text
    FormatEnergyUnit.format(:£, @last_year_£, :text) + 'pa, ' +
    FormatEnergyUnit.format(:relative_percent, @percent_difference_from_average_per_floor_area, :text) + ' ' +
    @simple_percent_difference_adjective + ' average'
  end

  private def dd_adj(asof_date)
    # overriden to full rather than 60% adjustment for storage heaters
    BenchmarkMetrics.normalise_degree_days(@school.temperatures, @school.holidays, :gas, asof_date)
  end
end
