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
require_relative '../gas/alert_gas_only_base.rb'
require_relative '../common/alert_floor_area_pupils_mixin.rb'

class AlertGasAnnualVersusBenchmark < AlertGasModelBase
  include AlertFloorAreaMixin
  attr_reader :last_year_kwh, :last_year_£, :previous_year_£, :last_year_co2

  attr_reader :one_year_benchmark_floor_area_kwh, :one_year_benchmark_floor_area_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£

  attr_reader :one_year_exemplar_floor_area_kwh, :one_year_exemplar_floor_area_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_co2, :one_year_exemplar_floor_area_co2

  attr_reader :one_year_gas_per_pupil_kwh, :one_year_gas_per_pupil_£
  attr_reader :one_year_gas_per_floor_area_kwh, :one_year_gas_per_floor_area_£
  attr_reader :one_year_gas_per_pupil_co2, :one_year_gas_per_floor_area_co2

  attr_reader :degree_day_adjustment
  attr_reader :last_year_degree_days, :previous_year_degree_days, :degree_days_annual_change
  attr_reader :temperature_adjusted_previous_year_kwh, :temperature_adjusted_percent

  attr_reader :one_year_gas_per_pupil_normalised_kwh, :one_year_gas_per_pupil_normalised_£
  attr_reader :one_year_gas_per_floor_area_normalised_kwh, :one_year_gas_per_floor_area_normalised_£

  attr_reader :per_floor_area_gas_benchmark_£
  attr_reader :percent_difference_from_average_per_floor_area

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
      previous_year_£: {
        description: 'Previous years gas consumption - £ including differential tariff',
        units:  {£: :gas},
        benchmark_code: '£pyr'
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
      one_year_exemplar_floor_area_co2: {
        description: 'Last years gas consumption for exemplar school, normalised by floor area - CO2 kg',
        units:  :co2
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
      one_year_saving_versus_exemplar_co2: {
        description: 'Annual difference in gas consumption versus exemplar school - CO2 kg (use adjective for sign)',
        units:  :co2
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
      last_year_degree_days: {
        description: 'Regional degree day adjustment; 60% of adjustment for Gas (not 100% heating consumption), 100% of Storage Heaters',
        units: Float,
        benchmark_code: 'ddly'
      },
      previous_year_degree_days: {
        description: 'Regional degree day adjustment; 60% of adjustment for Gas (not 100% heating consumption), 100% of Storage Heaters',
        units: Float,
        benchmark_code: 'ddpy'
      },
      degree_days_annual_change: {
        description: 'Year on year degree day change',
        units: :relative_percent,
        benchmark_code: 'ddan'
      },
      temperature_adjusted_previous_year_kwh: {
        description: 'Previous year kWh - temperature adjusted',
        units: :kwh,
        benchmark_code: 'kpya'
      },
      temperature_adjusted_percent: {
        description: 'Year on year kwh change temperature adjusted',
        units: :relative_percent,
        benchmark_code: 'adpc'
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
    I18n.t("#{i18n_prefix}.timescale")
  end

  def enough_data
    days_amr_data_with_asof_date(@asof_date) >= 364 ? :enough : :not_enough
  end

  protected def max_days_out_of_date_while_still_relevant
    ManagementSummaryTable::MAX_DAYS_OUT_OF_DATE_FOR_1_YEAR_COMPARISON
  end

  private def calculate(asof_date)
    raise EnergySparksNotEnoughDataException, "Not enough data: 1 year of data required, got #{days_amr_data} days" if enough_data == :not_enough
    @degree_day_adjustment = dd_adj(asof_date)

    calculate_annual_change_in_degree_days(asof_date)
    temperature_adjusted_stats(asof_date)

    @last_year_kwh = kwh(asof_date - 365, asof_date, :kwh)
    @last_year_£   = kwh(asof_date - 365, asof_date, :economic_cost)
    @last_year_co2 = kwh(asof_date - 365, asof_date, :co2)

    prev_date = asof_date - 366
    @previous_year_£ = kwh(prev_date - 365, prev_date, :economic_cost)

    @one_year_benchmark_floor_area_kwh   = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * floor_area(asof_date - 365, asof_date) / @degree_day_adjustment
    # benchmark £ using same tariff as school not benchmark tariff
    @one_year_benchmark_floor_area_£     = @one_year_benchmark_floor_area_kwh * defaulted_gas_tariff_£_per_kwh

    @one_year_saving_versus_benchmark_kwh = @last_year_kwh - @one_year_benchmark_floor_area_kwh
    @one_year_saving_versus_benchmark_£   = @last_year_£   - @one_year_benchmark_floor_area_£

    @one_year_exemplar_floor_area_kwh   = BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * floor_area(asof_date - 365, asof_date) / @degree_day_adjustment
    @one_year_exemplar_floor_area_£     = @one_year_exemplar_floor_area_kwh * defaulted_gas_tariff_£_per_kwh
    @one_year_exemplar_floor_area_co2   = gas_co2(@one_year_exemplar_floor_area_kwh)

    @one_year_saving_versus_exemplar_kwh = @last_year_kwh - @one_year_exemplar_floor_area_kwh
    @one_year_saving_versus_exemplar_£   = @last_year_£   - @one_year_exemplar_floor_area_£
    @one_year_saving_versus_exemplar_co2 = @last_year_co2 - @one_year_exemplar_floor_area_co2

    @one_year_gas_per_pupil_kwh       = @last_year_kwh / pupils(asof_date - 365, asof_date)
    @one_year_gas_per_pupil_£         = @last_year_£ / pupils(asof_date - 365, asof_date)
    @one_year_gas_per_floor_area_kwh  = @last_year_kwh / floor_area(asof_date - 365, asof_date)
    @one_year_gas_per_floor_area_£    = @last_year_£ / floor_area(asof_date - 365, asof_date)

    @one_year_gas_per_pupil_co2       = @last_year_co2  / pupils(asof_date - 365, asof_date)
    @one_year_gas_per_floor_area_co2  = @last_year_co2  / floor_area(asof_date - 365, asof_date)

    @one_year_gas_per_pupil_normalised_kwh        = @one_year_gas_per_pupil_kwh * @degree_day_adjustment
    @one_year_gas_per_pupil_normalised_£          = @one_year_gas_per_pupil_£ * @degree_day_adjustment
    @one_year_gas_per_floor_area_normalised_kwh   = @one_year_gas_per_floor_area_kwh * @degree_day_adjustment
    @one_year_gas_per_floor_area_normalised_£     = @one_year_gas_per_floor_area_£ * @degree_day_adjustment

    @per_floor_area_gas_£ = @last_year_£ / floor_area(asof_date - 365, asof_date)
    @per_floor_area_gas_benchmark_£ = @one_year_benchmark_floor_area_£ / floor_area(asof_date - 365, asof_date)
    @percent_difference_from_average_per_floor_area = percent_change(@per_floor_area_gas_benchmark_£, one_year_gas_per_floor_area_£)

    #BACKWARDS COMPATIBILITY: previously would have failed here as percent_change can return nil
    raise_calculation_error_if_missing(percent_difference_from_average_per_floor_area: @percent_difference_from_average_per_floor_area)

    set_savings_capital_costs_payback(Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£), nil, @one_year_saving_versus_exemplar_co2)

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@last_year_kwh - @one_year_benchmark_floor_area_kwh) / (@one_year_exemplar_floor_area_kwh - @one_year_benchmark_floor_area_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('AnnualGas')
  end
  alias_method :analyse_private, :calculate

  def one_year_saving_versus_exemplar_adjective
    return nil if @one_year_saving_versus_exemplar_kwh.nil?
    Adjective.adjective_for(@one_year_saving_versus_exemplar_kwh)
  end

  def one_year_saving_versus_benchmark_adjective
    return nil if @one_year_saving_versus_benchmark_kwh.nil?
    Adjective.adjective_for(@one_year_saving_versus_benchmark_kwh)
  end

  def percent_difference_adjective
    return "" if @percent_difference_from_average_per_floor_area.nil?
    Adjective.relative(@percent_difference_from_average_per_floor_area, :relative_to_1)
  end

  def simple_percent_difference_adjective
    return "" if @percent_difference_from_average_per_floor_area.nil?
    Adjective.relative(@percent_difference_from_average_per_floor_area, :simple_relative_to_1)
  end

  def summary
    I18n.t("analytics.annual_cost_with_adjective",
      cost: FormatEnergyUnit.format(:£, @last_year_£, :text),
      relative_percent: FormatEnergyUnit.format(:relative_percent, @percent_difference_from_average_per_floor_area, :text),
      adjective: simple_percent_difference_adjective)
  end

  private

  def dd_adj(asof_date)
    # overriden to full rather than 60% adjustment for storage heaters
    BenchmarkMetrics.normalise_degree_days(@school.temperatures, @school.holidays, :gas, asof_date)
  end

  def defaulted_gas_tariff_£_per_kwh
    @last_year_£ / @last_year_kwh
  end

  def last_year_date_range(asof_date)
    last_year_start_date = asof_date - 365
    last_year_start_date..asof_date
  end

  def previous_year_date_range(asof_date)
    ly = last_year_date_range(asof_date)
    previous_year_end_date = ly.first - 1
    previous_year_start_date = previous_year_end_date - 365
    previous_year_start_date..previous_year_end_date
  end

  def years_date_ranges_x2(asof_date)
    [previous_year_date_range(asof_date), last_year_date_range(asof_date)]
  end

  def temperature_adjusted_stats(asof_date)
    py, ly = years_date_ranges_x2(asof_date)
    model = calculate_model(asof_date)
    stats = model.heating_change_statistics(py, ly)
    unpack_temperature_adjusted_stats(stats) unless stats.nil?
  end

  def unpack_temperature_adjusted_stats(stats)
    @temperature_adjusted_previous_year_kwh = stats[:previous_year][:adjusted_annual_kwh]
    @temperature_adjusted_percent           = stats[:change][:adjusted_percent]
  end

  def calculate_annual_change_in_degree_days(asof_date)
    py, ly = years_date_ranges_x2(asof_date)

    @last_year_degree_days     = @school.temperatures.degree_days_in_date_range(ly.first, ly.last)
    @previous_year_degree_days = @school.temperatures.degree_days_in_date_range(py.first, py.last)

    @degree_days_annual_change = (@last_year_degree_days - @previous_year_degree_days) / @previous_year_degree_days
  end

  def kwh(date1, date2, data_type = :kwh)
    aggregate_meter.amr_data.kwh_date_range(date1, date2, data_type)
  rescue EnergySparksNotEnoughDataException=> e
    nil
  end
end
