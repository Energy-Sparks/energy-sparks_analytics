#======================== Electricity Baseload Analysis Versus Benchmark =====
require_relative 'alert_analysis_base.rb'
require_relative 'alert_floor_area_pupils_mixin.rb'

class AlertElectricityBaseloadVersusBenchmark < AlertBaseloadBase
  include AlertFloorAreaMixin
  PERCENT_TOO_HIGH_MARGIN = 1.10
  attr_reader :average_baseload_last_year_kw, :average_baseload_last_year_£, :average_baseload_last_year_kwh

  attr_reader :benchmark_per_pupil_kw, :exemplar_per_pupil_kw

  attr_reader :one_year_benchmark_by_pupil_kwh, :one_year_benchmark_by_pupil_£
  attr_reader :one_year_saving_versus_benchmark_kwh, :one_year_saving_versus_benchmark_£
  attr_reader :one_year_saving_versus_benchmark_adjective

  attr_reader :one_year_exemplar_by_pupil_kwh, :one_year_exemplar_by_pupil_£
  attr_reader :one_year_saving_versus_exemplar_kwh, :one_year_saving_versus_exemplar_£
  attr_reader :one_year_saving_versus_exemplar_adjective

  attr_reader :one_year_baseload_per_pupil_kw, :one_year_baseload_per_pupil_kwh, :one_year_baseload_per_pupil_£
  attr_reader :one_year_baseload_per_floor_area_kw, :one_year_baseload_per_floor_area_kwh, :one_year_baseload_per_floor_area_£

  attr_reader :summary

  def initialize(school, report_type = :baseloadbenchmark, meter = school.aggregated_electricity_meters)
    super(school, report_type, meter)
  end

  def self.template_variables
    specific = {'Annual electricity baseload usage versus benchmark' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    average_baseload_last_year_kw: {
      description: 'Average baseload last year kW',
      units:  { kw: :electricity},
      benchmark_code: 'lykw'
    },
    average_baseload_last_year_£: {
      description: 'Average baseload last year - value in £s (so kW * 24.0 * 365 * 15p or blended rate for differential tariff)',
      units:  :£,
      benchmark_code: 'lygb'
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
      units:  { kwh: :electricity},
    },
    one_year_exemplar_by_pupil_£: {
      description: 'Exemplar annual baseload cost £ for a school of this number of pupils and type (secondaries have higher baseloads)',
      units:  :£,
    },
    one_year_saving_versus_exemplar_kwh: {
      description: 'Potential annual kWh saving if school matched exemplar - absolute value, so needs to be used in conjuction with adjective',
      units:  { kwh: :electricity}
    },
    one_year_saving_versus_exemplar_£: {
      description: 'Potential annual £ saving if school matched exemplar - absolute value, so needs to be used in conjuction with adjective',
      units:  :£,
      benchmark_code: 'svex'
    },
    one_year_saving_versus_exemplar_adjective: {
      description: 'Adjective associated with whether saving is higher of lower than exemplar (higher or lower)',
      units:  String
    },

    one_year_baseload_per_pupil_kw: {
      description: 'kW baseload for school per pupil - for energy expert use',
      units:  { kw: :electricity},
      benchmark_code: 'blpp'
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
    },

    summary: {
      description: 'Description: annual benefit of moving to exemplar £',
      units: String
    }
  }.freeze

  def one_year_baseload_chart
    :alert_1_year_baseload
  end

  def timescale
    'last year'
  end

  def commentary
    [ { type: :html,  content: evaluation_html } ]
  end
  
  def evaluation_html
    text = %(
              <% if average_baseload_last_year_kw < benchmark_per_pupil_kw %>
                You are doing well, your average annual baseload is
                <%= format_kw(average_baseload_last_year_kw) %> compared with a
                well managed school of a similar size's
                <%= format_kw(benchmark_per_pupil_kw) %> and
                an examplar schools's 
                <%= FormatEnergyUnit.format(:kw, @exemplar_per_pupil_kw) %>,
                but there should still be opportunities to improve further.
              <% else %>
                Your average baseload last year was
                <%= format_kw(average_baseload_last_year_kw) %> compared with a
                well managed school of a similar size's
                <%= format_kw(benchmark_per_pupil_kw) %> and
                <%= FormatEnergyUnit.format(:kw, @exemplar_per_pupil_kw) %>
                at an exemplar school
                - there is significant room for improvement.
              <% end %>
            )
    ERB.new(text).result(binding)
  end

  def analysis_description
    'Comparison with other schools'
  end

  def enough_data
    is_aggregate_meter? && days_amr_data >= 1 ? :enough : :not_enough
  end

  private def calculate(asof_date)
    @average_baseload_last_year_kw = average_baseload_kw(asof_date, @meter)
    @average_baseload_last_year_£ = annual_average_baseload_£(asof_date, @meter)
    @average_baseload_last_year_kwh = annual_average_baseload_kwh(asof_date, @meter)

    electricity_tariff = blended_electricity_£_per_kwh(asof_date)

    @benchmark_per_pupil_kw = BenchmarkMetrics.recommended_baseload_for_pupils(pupils(asof_date - 365, asof_date), school_type)
    hours_in_year = 24.0 * 365.0

    @one_year_benchmark_by_pupil_kwh   = @benchmark_per_pupil_kw * hours_in_year
    @one_year_benchmark_by_pupil_£     = @one_year_benchmark_by_pupil_kwh * electricity_tariff

    @one_year_saving_versus_benchmark_kwh = @average_baseload_last_year_kwh - @one_year_benchmark_by_pupil_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_kwh * electricity_tariff
    @one_year_saving_versus_benchmark_adjective = @one_year_saving_versus_benchmark_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_benchmark_kwh = @one_year_saving_versus_benchmark_kwh
    @one_year_saving_versus_benchmark_£ = @one_year_saving_versus_benchmark_£

    @exemplar_per_pupil_kw = BenchmarkMetrics.exemplar_baseload_for_pupils(pupils(asof_date - 365, asof_date), school_type)

    @one_year_exemplar_by_pupil_kwh   = @exemplar_per_pupil_kw * hours_in_year
    @one_year_exemplar_by_pupil_£     = @one_year_exemplar_by_pupil_kwh * electricity_tariff

    @one_year_saving_versus_exemplar_kwh = @average_baseload_last_year_kwh - @one_year_exemplar_by_pupil_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_kwh * electricity_tariff
    @one_year_saving_versus_exemplar_adjective = @one_year_saving_versus_exemplar_kwh > 0.0 ? 'higher' : 'lower'
    @one_year_saving_versus_exemplar_kwh = @one_year_saving_versus_exemplar_kwh
    @one_year_saving_versus_exemplar_£ = @one_year_saving_versus_exemplar_£

    @one_year_baseload_per_pupil_kw        = @average_baseload_last_year_kw / pupils(asof_date - 365, asof_date)
    @one_year_baseload_per_pupil_kwh       = @average_baseload_last_year_kwh / pupils(asof_date - 365, asof_date)
    @one_year_baseload_per_pupil_£         = @average_baseload_last_year_£ / pupils(asof_date - 365, asof_date)

    @one_year_baseload_per_floor_area_kw   = @average_baseload_last_year_kw / floor_area(asof_date - 365, asof_date)
    @one_year_baseload_per_floor_area_kwh  = @average_baseload_last_year_kwh / floor_area(asof_date - 365, asof_date)
    @one_year_baseload_per_floor_area_£    = @average_baseload_last_year_£ / floor_area(asof_date - 365, asof_date)

    @summary = summary_text

    set_savings_capital_costs_payback(Range.new(@one_year_saving_versus_exemplar_£, @one_year_saving_versus_exemplar_£), nil)

    # rating: benchmark value = 4.0, exemplar = 10.0
    percent_from_benchmark_to_exemplar = (@average_baseload_last_year_kwh - @one_year_benchmark_by_pupil_kwh) / (@one_year_exemplar_by_pupil_kwh - @one_year_benchmark_by_pupil_kwh)
    uncapped_rating = percent_from_benchmark_to_exemplar * (10.0 - 4.0) + 4.0
    @rating = [[uncapped_rating, 10.0].min, 0.0].max.round(2)

    @status = @rating < 6.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('ElectricityBaseload')
  end
  alias_method :analyse_private, :calculate

  def summary_text
    if @one_year_saving_versus_exemplar_£ > 0
      'Your baseload is high, reducing it could save ' +
      FormatEnergyUnit.format(:£, @one_year_saving_versus_exemplar_£, :text) + 'pa'
    else
      'You are doing well - you are an exemplar school'
    end
  end

  private def dashboard_adjective
    @average_baseload_last_year_kw > @benchmark_per_pupil_kw * 1.05 ? 'too high' : 'good'
  end

  def dashboard_summary
    'Your electricity baseload is ' + dashboard_adjective
  end

  def dashboard_detail
    text = %{
      Your baseload over the last year of <%= FormatEnergyUnit.format(:kw, @average_baseload_last_year_kw) %> is <%= dashboard_adjective %>
      compared with average usage at other schools of <%= FormatEnergyUnit.format(:kw, @benchmark_per_pupil_kw) %> (pupil based),
      and <%= FormatEnergyUnit.format(:kw, @exemplar_per_pupil_kw) %> at an exemplar school.
    }
    ERB.new(text).result(binding)
  end

  def is_aggregate_meter?
    @school.aggregated_electricity_meters.mpxn == @meter.mpxn
  end
end