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
  def initialize(school)
    super(school, :annualgasbenchmark)
  end

  def analyse_private(asof_date)
    annual_kwh = kwh(asof_date - 365, asof_date)
    annual_kwh_per_pupil_benchmark = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_PUPIL * @school.number_of_pupils
    annual_kwh_per_floor_area_benchmark = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * @school.floor_area

    @analysis_report.term = :longterm
    @analysis_report.add_book_mark_to_base_url('AnnualGasBenchmark')

    if annual_kwh > annual_kwh_per_pupil_benchmark ||
        annual_kwh > annual_kwh_per_floor_area_benchmark
      @analysis_report.summary = 'Your annual gas consumption is high compared with the average school'
      text = commentary(annual_kwh, 'too high', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = annual_kwh / annual_kwh_per_pupil_benchmark
      per_floor_area_ratio = annual_kwh / annual_kwh_per_floor_area_benchmark
      @analysis_report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your gas consumption is good'
      text = commentary(annual_kwh, 'good', annual_kwh_per_pupil_benchmark, annual_kwh_per_floor_area_benchmark)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end

  def commentary(annual_kwh, comparative_text, pupil_benchmark, floor_area_benchmark)
    annual_cost = annual_kwh * BenchmarkMetrics::GAS_PRICE
    benchmark_pupil_cost = pupil_benchmark * BenchmarkMetrics::GAS_PRICE
    benchmark_m2_cost = floor_area_benchmark * BenchmarkMetrics::GAS_PRICE
    text = ''
    text += sprintf('Your gas usage over the last year of %.0f kWh/£%.0f is %s, ', annual_kwh, annual_cost, comparative_text)
    text += sprintf('compared with benchmarks of %.0f kWh/£%.0f (pupil based) ', pupil_benchmark, benchmark_pupil_cost)
    text += sprintf('and %.0f kWh/£%.0f (floor area based) ', floor_area_benchmark, benchmark_m2_cost)
    text
  end

  def kwh(date1, date2)
    amr_data = @school.aggregated_heat_meters.amr_data
    amr_data.kwh_date_range(date1, date2)
  end
end