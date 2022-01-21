#======================== Electricity Annual kWh Versus Benchmark =============
require_relative '../common/alert_analysis_base.rb'
require_relative '../common/alert_floor_area_pupils_mixin.rb'

class AlertElectricityAnnualVersusBenchmark < AlertElectricityOnlyBase
  include AlertFloorAreaMixin
  attr_reader :last_year_kwh, :last_year_£, :last_year_co2

  attr_reader :one_year_benchmark_by_pupil_kwh, :one_year_benchmark_by_pupil_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_by_pupil_kwh, :one_year_exemplar_by_pupil_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£, :one_year_saving_versus_exemplar_co2
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_electricity_per_pupil_kwh, :one_year_electricity_per_pupil_£, :one_year_electricity_per_pupil_co2
  attr_reader :one_year_electricity_per_floor_area_kwh, :one_year_electricity_per_floor_area_£

  attr_reader :per_pupil_electricity_benchmark_£
  attr_reader :percent_difference_from_average_per_pupil, :percent_difference_adjective
  attr_reader :simple_percent_difference_adjective, :summary

  def initialize(school)
    super(school, :annualelectricitybenchmark)
  end

  def self.template_variables
    specific = {'Annual electricity usage versus benchmark' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end
  
  TEMPLATE_VARIABLES = {
    last_year_kwh: {
      description: 'Last years electricity consumption - kwh',
      units:  {kwh: :electricity},
      benchmark_code: 'klyr'
    },
    last_year_£: {
      description: 'Last years electricity consumption - £ including differential tariff',
      units:  {£: :electricity},
      benchmark_code: '£lyr'
    },
    last_year_co2: {
      description: 'Last years electricity CO2 kg',
      units:  :co2,
      benchmark_code: 'co2y'
    },
    one_year_benchmark_by_pupil_kwh: {
      description: 'Last years electricity consumption for benchmark/average school, normalised by pupil numbers - kwh',
      units:  {kwh: :electricity}
    },
    one_year_benchmark_by_pupil_£: {
      description: 'Last years electricity consumption for benchmark/average school, normalised by pupil numbers - £',
      units:  {£: :electricity}
    },
    one_year_saving_versus_benchmark_kwh: {
      description: 'Annual difference in electricity consumption versus benchmark/average school - kwh (use adjective for sign)',
      units:  {kwh: :electricity}
    },
    one_year_saving_versus_benchmark_£: {
      description: 'Annual difference in electricity consumption versus benchmark/average school - £ (use adjective for sign)',
      units:  {£: :electricity}
    },
    one_year_saving_versus_benchmark_adjective: {
      description: 'Adjective: higher or lower: electricity consumption versus benchmark/average school',
      units:  String
    },
    one_year_exemplar_by_pupil_kwh: {
      description: 'Last years electricity consumption for exemplar school, normalised by pupil numbers - kwh',
      units:  {kwh: :electricity}
    },
    one_year_exemplar_by_pupil_£: {
      description: 'Last years electricity consumption for exemplar school, normalised by pupil numbers - £',
      units:  {£: :electricity}
    },
    one_year_saving_versus_exemplar_kwh: {
      description: 'Annual difference in electricity consumption versus exemplar school - kwh (use adjective for sign)',
      units:  {kwh: :electricity}
    },
    one_year_saving_versus_exemplar_£: {
      description: 'Annual difference in electricity consumption versus exemplar school - £ (use adjective for sign)',
      units:  {£: :electricity},
      benchmark_code: '£esav'
    },
    one_year_saving_versus_exemplar_co2: {
      description: 'Annual difference in electricity consumption versus exemplar school - co2 (use adjective for sign)',
      units:  :c02,
    },
    one_year_saving_versus_exemplar_adjective: {
      description: 'Adjective: higher or lower: electricity consumption versus exemplar school',
      units:  String
    },
    one_year_electricity_per_pupil_kwh: {
      description: 'Per pupil annual electricity usage - kwh - required for PH analysis, not alerts',
      units:  {kwh: :electricity},
      benchmark_code: 'kpup'
    },
    one_year_electricity_per_pupil_£: {
      description: 'Per pupil annual electricity usage - £ - required for PH analysis, not alerts',
      units:  {£: :electricity},
      benchmark_code: '£pup'
    },
    one_year_electricity_per_pupil_co2: {
      description: 'Per pupil annual electricity usage - co2 - required for PH analysis, not alerts',
      units:  :co2,
      benchmark_code: 'cpup'
    },
    one_year_electricity_per_floor_area_kwh: {
      description: 'Per floor area annual electricity usage - kwh - required for PH analysis, not alerts',
      units:  {kwh: :electricity}
    },
    one_year_electricity_per_floor_area_£: {
      description: 'Per floor area annual electricity usage - £ - required for PH analysis, not alerts',
      units:  {£: :electricity}
    },
    per_pupil_electricity_benchmark_£: {
      description: 'Per pupil annual electricity usage - £',
      units:  {£: :electricity}
    },
    percent_difference_from_average_per_pupil: {
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

  def timescale
    'last year'
  end

  def enough_data
    days_amr_data_with_asof_date(@asof_date) >= 364 ? :enough : :not_enough
  end

  def benchmark_dates(asof_date)
    [asof_date, asof_date - 364]
  end

  protected def max_days_out_of_date_while_still_relevant
    ManagementSummaryTable::MAX_DAYS_OUT_OF_DATE_FOR_1_YEAR_COMPARISON
  end

  private def calculate(asof_date)
    raise EnergySparksNotEnoughDataException, "Not enough data: 1 year of data required, got #{days_amr_data} days" if enough_data == :not_enough
    @last_year_kwh = kwh(asof_date - 365, asof_date, :kwh)
    @last_year_£   = kwh(asof_date - 365, asof_date, :economic_cost)
    @last_year_co2 = kwh(asof_date - 365, asof_date, :co2)

    @one_year_benchmark_by_pupil_kwh   = BenchmarkMetrics.benchmark_annual_electricity_usage_kwh(school_type, pupils(asof_date - 365, asof_date))
    @one_year_benchmark_by_pupil_£     = @one_year_benchmark_by_pupil_kwh * blended_electricity_£_per_kwh
    @one_year_saving_versus_benchmark_kwh = @last_year_kwh - @one_year_benchmark_by_pupil_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * blended_electricity_£_per_kwh
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh.magnitude
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£.magnitude

    @one_year_exemplar_by_pupil_kwh   = BenchmarkMetrics.exemplar_annual_electricity_usage_kwh(school_type, pupils(asof_date - 365, asof_date))
    @one_year_exemplar_by_pupil_£     = @one_year_exemplar_by_pupil_kwh * blended_electricity_£_per_kwh

    @one_year_saving_versus_exemplar_kwh = @last_year_kwh - @one_year_exemplar_by_pupil_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * blended_electricity_£_per_kwh
    @one_year_saving_versus_exemplar_co2 = @one_year_saving_versus_exemplar_kwh * blended_co2_per_kwh
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh.magnitude
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£.magnitude
    @one_year_saving_versus_exemplar_co2 = @one_year_saving_versus_exemplar_co2.magnitude

    @one_year_electricity_per_pupil_kwh       = @last_year_kwh / pupils(asof_date - 365, asof_date)
    @one_year_electricity_per_pupil_£         = @last_year_£ / pupils(asof_date - 365, asof_date)
    @one_year_electricity_per_pupil_co2       = @last_year_co2 / pupils(asof_date - 365, asof_date)
    @one_year_electricity_per_floor_area_kwh  = @last_year_kwh / floor_area(asof_date - 365, asof_date)
    @one_year_electricity_per_floor_area_£    = @last_year_£ / floor_area(asof_date - 365, asof_date)

    set_savings_capital_costs_payback(Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£), capital_cost, @one_year_saving_versus_exemplar_co2)

    @per_pupil_electricity_£ = @last_year_£ / pupils(asof_date - 365, asof_date)
    @per_pupil_electricity_benchmark_£ = @one_year_benchmark_by_pupil_£ / pupils(asof_date - 365, asof_date)
    @percent_difference_from_average_per_pupil = percent_change(@per_pupil_electricity_benchmark_£, one_year_electricity_per_pupil_£)
    @percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_pupil, :relative_to_1)
    @simple_percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_pupil, :simple_relative_to_1)

    @summary = summary_text

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@last_year_kwh - @one_year_benchmark_by_pupil_kwh) / (@one_year_exemplar_by_pupil_kwh - @one_year_benchmark_by_pupil_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('AnnualElectricity')
  end
  alias_method :analyse_private, :calculate

  def summary_text
    FormatEnergyUnit.format(:£, @last_year_£, :text) + 'pa, ' +
    FormatEnergyUnit.format(:relative_percent, @percent_difference_from_average_per_pupil, :text) + ' ' +
    @simple_percent_difference_adjective + ' average'
  end

  def kwh(date1, date2, data_type = :kwh)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.kwh_date_range(date1, date2, data_type)
  end
end