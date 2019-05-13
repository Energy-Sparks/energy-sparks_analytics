#======================== Electricity Baseload Analysis Versus Benchmark =====
require_relative 'alert_analysis_base.rb'

class AlertElectricityBaseloadVersusBenchmark < AlertElectricityOnlyBase
  PERCENT_TOO_HIGH_MARGIN = 1.10
  attr_reader :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area # historic attributes, remove post template variables but check doesn't break advice TODO(PH, 11Apr2019)

  attr_reader :average_baseload_last_year_kw, :average_baseload_last_year_£, :average_baseload_last_year_kwh

  attr_reader :benchmark_per_pupil_kw, :exemplar_per_pupil_kw

  attr_reader :one_year_benchmark_by_pupil_kwh, :one_year_benchmark_by_pupil_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_by_pupil_kwh, :one_year_exemplar_by_pupil_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_saving_£

  attr_reader :one_year_baseload_per_pupil_kw, :one_year_baseload_per_pupil_kwh, :one_year_baseload_per_pupil_£
  attr_reader :one_year_baseload_per_floor_area_kw, :one_year_baseload_per_floor_area_kwh, :one_year_baseload_per_floor_area_£

  def initialize(school)
    super(school, :baseloadbenchmark)
  end

  def self.template_variables
    specific = {'Annual electricity baseload usage versus benchmark' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    average_baseload_last_year_kw: {
      description: 'Average baseload last year kW',
      units:  { kw: :electricity}
    },
    average_baseload_last_year_£: {
      description: 'Average baseload last year - value in £s (so kW * 24.0 * 365 * 12p or blended rate for differential tariff)',
      units:  :£
    },
    average_baseload_last_year_kwh: {
      description: 'Average baseload last year - value in £s (so kW * 24.0 * 365)',
      units:  { kwh: :electricity}
    },
    benchmark_per_pupil_kw: {
      description: 'Benchmark baseload kW for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  { kw: :electricity}
    },
    exemplar_per_pupil_kw: {
      description: 'Exemplar baseload kW for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  { kw: :electricity}
    },

    one_year_benchmark_by_pupil_kwh: {
      description: 'Benchmark annual baseload kWh for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  { kwh: :electricity}
    },
    one_year_benchmark_by_pupil_£: {
      description: 'Benchmark annual baseload cost £ for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  :£
    },
    one_year_saving_versus_benchmark_kwh: {
      description: 'Potential annual kWh saving if school matched benchmark - absolute value, so needs to be used in conjuction with adjective',
      units:  { kwh: :electricity}
    },
    one_year_saving_versus_benchmark_£: {
      description: 'Potential annual £ saving if school matched benchmark - absolute value, so needs to be used in conjuction with adjective',
      units:  :£
    },
    one_year_saving_versus_benchmark_adjective: {
      description: 'Adjective associated with whether saving is higher of lower than benchmark (higher or lower)',
      units:  String
    },

    one_year_exemplar_by_pupil_kwh: {
      description: 'Exemplar annual baseload kWh for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  { kwh: :electricity}
    },
    one_year_exemplar_by_pupil_£: {
      description: 'Exemplar annual baseload cost £ for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  :£
    },
    one_year_saving_versus_exemplar_kwh: {
      description: 'Potential annual kWh saving if school matched exemplar - absolute value, so needs to be used in conjuction with adjective',
      units:  { kwh: :electricity}
    },
    one_year_saving_versus_exemplar_£: {
      description: 'Potential annual £ saving if school matched exemplar - absolute value, so needs to be used in conjuction with adjective',
      units:  :£
    },
    one_year_saving_versus_exemplar_adjective: {
      description: 'Adjective associated with whether saving is higher of lower than exemplar (higher or lower)',
      units:  String
    },

    one_year_baseload_per_pupil_kw: {
      description: 'kW baseload for school per pupil - for energy expert use',
      units:  { kw: :electricity}
    },
    one_year_baseload_per_pupil_kwh: {
      description: 'kwh baseload for school per pupil - for energy expert use',
      units:  { kwh: :electricity}
    },
    one_year_baseload_per_pupil_£: {
      description: '£ baseload for school per pupil - for energy expert use',
      units:  :£
    },

    one_year_baseload_per_floor_area_kw: {
      description: 'kW baseload for school per floor area - for energy expert use',
      units:  { kw: :electricity}
    },
    one_year_baseload_per_floor_area_kwh: {
      description: 'kwh baseload for school per floor area - for energy expert use',
      units:  { kwh: :electricity}
    },
    one_year_baseload_per_floor_area_£: {
      description: '£ baseload for school per floor area - for energy expert use',
      units:  :£
    },

    one_year_baseload_chart: {
      description: 'chart of last years baseload',
      units: :chart
    }
  }.freeze

  def one_year_baseload_chart
    :alert_1_year_baseload
  end

  def timescale
    'last year'
  end

  def enough_data
    days_amr_data >= 364 ? :enough : (days_amr_data >= 180 ? :minimum_might_not_be_accurate : :not_enough)
  end

  private def calculate(asof_date)
    @average_baseload_last_year_kw, _days_sample = annual_average_baseload_kw(asof_date)
    @average_baseload_last_year_£ = annual_average_baseload_£(asof_date)
    @average_baseload_last_year_kwh = annual_average_baseload_kwh(asof_date)

    electricity_tariff = blended_electricity_£_per_kwh(asof_date)

    @benchmark_per_pupil_kw = BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
    hours_in_year = 24.0 * 365.0

    @one_year_benchmark_by_pupil_kwh   = @benchmark_per_pupil_kw * hours_in_year
    @one_year_benchmark_by_pupil_£     = @one_year_benchmark_by_pupil_kwh * electricity_tariff

    @one_year_saving_versus_benchmark_kwh = @average_baseload_last_year_kwh - @one_year_benchmark_by_pupil_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * electricity_tariff
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh.magnitude
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£.magnitude

    @exemplar_per_pupil_kw = BenchmarkMetrics.exemplar_baseload_for_pupils(pupils, school_type)

    @one_year_exemplar_by_pupil_kwh   = @exemplar_per_pupil_kw * hours_in_year
    @one_year_exemplar_by_pupil_£     = @one_year_exemplar_by_pupil_kwh * electricity_tariff

    @one_year_saving_versus_exemplar_kwh = @average_baseload_last_year_kwh - @one_year_exemplar_by_pupil_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * electricity_tariff
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh.magnitude
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£.magnitude

    @one_year_baseload_per_pupil_kw        = @average_baseload_last_year_kw / pupils
    @one_year_baseload_per_pupil_kwh       = @average_baseload_last_year_kwh / pupils
    @one_year_baseload_per_pupil_£         = @average_baseload_last_year_£ / pupils

    @one_year_baseload_per_floor_area_kw   = @average_baseload_last_year_kw / floor_area
    @one_year_baseload_per_floor_area_kwh  = @average_baseload_last_year_kwh / floor_area
    @one_year_baseload_per_floor_area_£    = @average_baseload_last_year_£ / floor_area

    @one_year_saving_£ = Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£)

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@average_baseload_last_year_kwh - @one_year_benchmark_by_pupil_kwh) / (@one_year_exemplar_by_pupil_kwh - @one_year_benchmark_by_pupil_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('ElectricityBaseload')
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    @avg_baseload, days_sample = annual_average_baseload_kw(asof_date)

    @benchmark_per_pupil = BenchmarkMetrics.recommended_baseload_for_pupils(pupils, school_type)
    @benchmark_per_floor_area = BenchmarkMetrics.recommended_baseload_for_floor_area(floor_area, school_type)

    @analysis_report.term = :longterm
    @analysis_report.add_book_mark_to_base_url('ElectricityBaseload')

    if @avg_baseload > (@benchmark_per_pupil * PERCENT_TOO_HIGH_MARGIN) || @avg_baseload > (@benchmark_per_floor_area * PERCENT_TOO_HIGH_MARGIN)
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