=begin
#======================== Electricity Baseload Analysis Versus Benchmark =====
require_relative 'alert_analysis_base.rb'

class AlertElectricityBaseloadVersusBenchmarkNew < AlertAnalysisBase
  attr_reader :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area

  TEMPLATE_VARIABLES = {
    # units
    benchmark_per_pupil: {
      description: "This is the benchmark per pupil, measured in kW",
      example_data: { poor: '10.0', good: '20.0' },
      units: "kW"
    },
    benchmark_per_floor_area: {
      description: "This is the benchmark per floor area, measured in kW",
      example_data: { poor: '10.0', good: '20.0' },
      units: "kW"
    },
    baseload: {
      description: "This is the electricity baseload, measured in kW",
      example_data: { poor: '1000.0', good: '200.0' },
      units: "kW"
    },
  }.freeze

  def initialize(school)
    super(school)
  end

  # This would live in the base class
  def self.template_variables
    TEMPLATE_VARIABLES
  end

  def analyse(asof_date)

    # Just as an indication for the average baseload below
    @asof_date = asof_date

    @analysis_report.term = :longterm
    @analysis_report.add_book_mark_to_base_url('ElectricityBaseload')

    if avg_baseload > benchmark_per_pupil || avg_baseload > @benchmark_per_floor_area
      per_pupil_ratio = avg_baseload / benchmark_per_pupil
      per_floor_area_ratio = avg_baseload / benchmark_per_floor_area

      @analysis_report.rating = AlertReport::MAX_RATING * (per_pupil_ratio > per_floor_area_ratio ? (1.0 / per_pupil_ratio) : (1.0 / per_floor_area_ratio))
      @analysis_report.status = :poor
    # For example
    elsif we_do_not_have_enough_data
      @analysis_report.status = :insufficient_data
    elsif no_action_required # i.e. school holiday alert out of school holidays
      @analysis_report.status = :no_action_required
    else
      @analysis_report.status = :good
    end
  end

  # All data is returned as strings
  def template_data
    {
      benchmark_per_pupil: benchmark_per_pupil,
      baseload: avg_baseload,
      benchmark_per_floor_area: benchmark_per_floor_area,
      chart_data: chart_data # This is for any chart data which the front end might want to render
      chart_html: chart_html # This would be in the interim to allow for charts to be rendered as they are at the moment for some alerts.
    }
  end

  def benchmark_per_pupil
    # Lazy load
    @benchmark_per_pupil ||= BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
  end

  def benchmark_per_floor_area
    @benchmark_per_floor_area ||= BenchmarkMetrics.recommended_baseload_for_floor_area(floor_area, school_type)
  end

  def avg_baseload
    @avg_baseload ||= average_baseload(@asof_date - 365, @asof_date)
  end

  def average_baseload(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.average_baseload_kw_date_range(date1, date2)
  end
end
=end