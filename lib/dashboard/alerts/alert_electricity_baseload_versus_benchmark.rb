#======================== Electricity Baseload Analysis Versus Benchmark =====
require_relative 'alert_analysis_base.rb'

class AlertElectricityBaseloadVersusBenchmark < AlertAnalysisBase
  attr_reader :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area

  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    @avg_baseload = average_baseload(asof_date - 365, asof_date)
    @benchmark_per_pupil = BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
    @benchmark_per_floor_area = BenchmarkMetrics.recommended_baseload_for_floor_area(floor_area, school_type)

    report = AlertReport.new(:baseloadbenchmark)
    report.term = :longterm
    report.add_book_mark_to_base_url('ElectricityBaseload')

    if @avg_baseload > @benchmark_per_pupil || @avg_baseload > @benchmark_per_floor_area
      report.summary = 'Your electricity baseload is too high'
      text = commentary(@avg_baseload, 'too high', @benchmark_per_pupil, @benchmark_per_floor_area)
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = @avg_baseload / @benchmark_per_pupil
      per_floor_area_ratio = @avg_baseload / @benchmark_per_floor_area
      report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      report.status = :poor
    else
      report.summary = 'Your electricity baseload is good'
      text = commentary(@avg_baseload, 'good', @benchmark_per_pupil, @benchmark_per_floor_area)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.rating = 10.0
      report.status = :good

    end
    report.add_detail(description1)
    add_report(report)
  end

  def commentary(baseload, comparative_text, pupil_benchmark, floor_area_benchmark)
    text = sprintf('Your baseload over the last year of %.1f kW is %s, ', baseload, comparative_text)
    text += sprintf('compared with average usage at other schools of %.1f kW (pupil based) ', pupil_benchmark)
    text += sprintf('and %.1f kW (for a similar floor area).', floor_area_benchmark)
    text
  end

  def average_baseload(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.average_baseload_kw_date_range(date1, date2)
  end
end