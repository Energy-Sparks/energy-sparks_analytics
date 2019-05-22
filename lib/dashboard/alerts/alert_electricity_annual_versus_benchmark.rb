#======================== Electricity Annual kWh Versus Benchmark =============
require_relative 'alert_analysis_base.rb'

class AlertElectricityAnnualVersusBenchmark < AlertElectricityOnlyBase
  attr_reader :last_year_kwh, :last_year_£

  attr_reader :one_year_benchmark_by_pupil_kwh, :one_year_benchmark_by_pupil_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_by_pupil_kwh, :one_year_exemplar_by_pupil_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_electricity_per_pupil_kwh, :one_year_electricity_per_pupil_£
  attr_reader :one_year_electricity_per_floor_area_kwh, :one_year_electricity_per_floor_area_£

  attr_reader :one_year_saving_£

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
      units:  {kwh: :electricity}
    },
    last_year_£: {
      description: 'Last years electricity consumption - £ including differential tariff',
      units:  {£: :electricity}
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
      units:  {£: :electricity}
    },
    one_year_saving_versus_exemplar_adjective: {
      description: 'Adjective: higher or lower: electricity consumption versus exemplar school',
      units:  String
    },

    one_year_electricity_per_pupil_kwh: {
      description: 'Per pupil annual electricity usage - kwh - required for PH analysis, not alerts',
      units:  {kwh: :electricity}
    },
    one_year_electricity_per_pupil_£: {
      description: 'Per pupil annual electricity usage - £ - required for PH analysis, not alerts',
      units:  {£: :electricity}
    },
    one_year_electricity_per_floor_area_kwh: {
      description: 'Per floor area annual electricity usage - kwh - required for PH analysis, not alerts',
      units:  {kwh: :electricity}
    },
    one_year_electricity_per_floor_area_£: {
      description: 'Per floor area annual electricity usage - £ - required for PH analysis, not alerts',
      units:  {£: :electricity}
    }
  }

  def timescale
    'last year'
  end

  def enough_data
    days_amr_data >= 364 ? :enough : :not_enough
  end

  private def calculate(asof_date)
    @last_year_kwh = kwh(asof_date - 365, asof_date, :kwh)
    @last_year_£   = kwh(asof_date - 365, asof_date, :economic_cost)

    @one_year_benchmark_by_pupil_kwh   = BenchmarkMetrics.benchmark_annual_electricity_usage_kwh(school_type, pupils)
    @one_year_benchmark_by_pupil_£     = @one_year_benchmark_by_pupil_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    @one_year_saving_versus_benchmark_kwh = @last_year_kwh - @one_year_benchmark_by_pupil_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh.magnitude
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£.magnitude

    @one_year_exemplar_by_pupil_kwh   = BenchmarkMetrics.exemplar_annual_electricity_usage_kwh(school_type, pupils)
    @one_year_exemplar_by_pupil_£     = @one_year_benchmark_by_pupil_kwh * BenchmarkMetrics::ELECTRICITY_PRICE

    @one_year_saving_versus_exemplar_kwh = @last_year_kwh - @one_year_exemplar_by_pupil_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh.magnitude
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£.magnitude

    @one_year_electricity_per_pupil_kwh       = @last_year_kwh / pupils
    @one_year_electricity_per_pupil_£         = @last_year_£ / pupils
    @one_year_electricity_per_floor_area_kwh  = @last_year_kwh / floor_area
    @one_year_electricity_per_floor_area_£    = @last_year_£ / floor_area

    @one_year_saving_£ = Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£)

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@last_year_kwh - @one_year_benchmark_by_pupil_kwh) / (@one_year_exemplar_by_pupil_kwh - @one_year_benchmark_by_pupil_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('AnnualElectricity')
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    annual_kwh = kwh(asof_date - 365, asof_date)
    annual_kwh_per_pupil_benchmark = BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * @school.number_of_pupils
    annual_kwh_per_floor_area_benchmark = BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_M2 * @school.floor_area

    @analysis_report.term = :longterm
    @analysis_report.add_book_mark_to_base_url('AnnualElectricity')

    if annual_kwh > annual_kwh_per_pupil_benchmark || annual_kwh > annual_kwh_per_floor_area_benchmark
      @analysis_report.summary = 'Your annual electricity usage is high compared with the average school'
      text = commentary(annual_kwh, 'too high', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = annual_kwh / annual_kwh_per_pupil_benchmark
      per_floor_area_ratio = annual_kwh / annual_kwh_per_floor_area_benchmark
      @analysis_report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your annual electricity usage is good'
      text = commentary(annual_kwh, 'good', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end

  def commentary(annual_kwh, comparative_text, pupil_benchmark, floor_area_benchmark)
    annual_cost = annual_kwh * BenchmarkMetrics::ELECTRICITY_PRICE
    benchmark_pupil_cost = pupil_benchmark * BenchmarkMetrics::ELECTRICITY_PRICE
    benchmark_m2_cost = floor_area_benchmark * BenchmarkMetrics::ELECTRICITY_PRICE
    text = 'Your annual electricity usage is ' + comparative_text + '.'
    text += sprintf('Your electricity usage over the last year of %.0f kWh/£%.0f is %s, ', annual_kwh, annual_cost, comparative_text)
    text += sprintf('compared with benchmarks of %.0f kWh/£%.0f (pupil based) ', pupil_benchmark, benchmark_pupil_cost)
    text += sprintf('and %.0f kWh/£%.0f (floor area based).', floor_area_benchmark, benchmark_m2_cost)
    text
  end

  def kwh(date1, date2, data_type = :kwh)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.kwh_date_range(date1, date2, data_type)
  end
end