#======================== Electricity Baseload Analysis Versus Benchmark =====
require_relative 'alert_analysis_base.rb'

class AlertElectricityBaseloadVersusBenchmark < AlertElectricityOnlyBase
  attr_reader :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area

  def initialize(school)
    super(school, :baseloadbenchmark)
  end

  def analyse_private(asof_date)

    @avg_baseload, days_sample = baseload(asof_date)

    @benchmark_per_pupil = BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
    @benchmark_per_floor_area = BenchmarkMetrics.recommended_baseload_for_floor_area(floor_area, school_type)

    @analysis_report.term = :longterm
    @analysis_report.add_book_mark_to_base_url('ElectricityBaseload')

    if @avg_baseload > @benchmark_per_pupil || @avg_baseload > @benchmark_per_floor_area
      @analysis_report.summary = 'Your electricity baseload is too high'
      text = commentary(@avg_baseload, 'too high', @benchmark_per_pupil, @benchmark_per_floor_area)
      if days_sample < 3 * 30
        text += '(we have less that 3 months of data from which to calculate your baseload)'
      end
      description1 = AlertDescriptionDetail.new(:text, text)

      per_pupil_ratio = @avg_baseload / @benchmark_per_pupil
      per_floor_area_ratio = @avg_baseload / @benchmark_per_floor_area
      @analysis_report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your electricity baseload is good'
      text = commentary(@avg_baseload, 'good', @benchmark_per_pupil, @benchmark_per_floor_area)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good

    end
    @analysis_report.add_detail(description1)
  end

  def commentary(baseload, comparative_text, pupil_benchmark, floor_area_benchmark)
    text = sprintf('Your baseload over the last year of %.1f kW is %s, ', baseload, comparative_text)
    text += sprintf('compared with average usage at other schools of %.1f kW (pupil based) ', pupil_benchmark)
    text += sprintf('and %.1f kW (for a similar floor area).', floor_area_benchmark)
    text
  end
end