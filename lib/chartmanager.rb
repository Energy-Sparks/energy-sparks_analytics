# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
#
require_relative 'aggregator'
require 'benchmark'
require 'awesome_print'

class ChartManager
  attr_reader :standard_charts, :school

  # rubocop:disable Style/ClassVars, Style/SymbolArray
  @@standard_charts = [
    :day,
    :group_by_month,
    :group_by_week,
    :day_of_week,
    :benchmark,
    :daytype_breakdown,
    :thermostatic,
    :cusum,
    :baseload,
    :summer_hot_water,
    :intraday_aggregate,
    :intraday
  ]

  @@standard_chart_configuration = {
    #
    # chart confif parameters:
    # name:               As appears in title of chart; passed through back to output with addition data e.g. total kWh
    # series_breakdown:   :fuel || :daytype || :heatingon - so fuel auto splits into [gas, electricity]
    #                      daytype into holidays, weekends, schools in and out of hours
    #                      heatingon - heating and non heating days
    #                     ultimately the plan is to support a list of breaddowns
    # chart1_type:        bar || column || pie || scatter - gets passed through back to output
    # chart1_subtype:     generally not present, if present 'stacked' is its most common value
    # x_axis:             grouping of data on xaxis: :intraday :day :week :dayofweek :month :year :academicyear
    # timescale:          period overwhich data aggregated - assumes tie covering all available data if missing
    # yaxis_units:        :£ etc. TODO PG,23May2018) - complete documentation
    # data_types:         an array e.g. [:metereddata, :predictedheat] - assumes :metereddata if not present
    #
    # rubocop:disable Style/HashSyntax, Layout/SpaceInsideHashLiteralBraces

    benchmark:  {
      name:             'Benchmark Comparison',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      x_axis:           :year,
      series_breakdown: :fuel,
      yaxis_units:      :£,
      yaxis_scaling:    :none
      # timescale:        :year
    },
    daytype_breakdown: {
      name:             'Day Type: Gas',
      chart1_type:      :pie,
      meter_definition: :allheat,
      x_axis:           :nodatebuckets,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    group_by_week_gas: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kw: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh_pupil: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :per_pupil,
      y2_axis:          :degreedays
    },
    group_by_week_gas_co2_floor_area: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :co2,
      yaxis_scaling:    :per_floor_area,
      y2_axis:          :degreedays
    },
    group_by_week_gas_library_books: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :library_books,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_electricity: {
      name:             'By Week: Electricity',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      # timescale:        :year,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    gas_latest_years:  {
      name:             'Gas Use Over Last Few Years (to date)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    gas_latest_academic_years:  {
      name:             'Gas Use Over Last Few Academic Years',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :academicyear,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    gas_by_day_of_week:  {
      name:             'Gas Use By Day of the Week (last year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_day_of_week:  {
      name:             'Electricity Use By Day of the Week (last year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :per_200_pupils
    },
    electricity_by_month_acyear_0_1:  {
      name:             'Electricity Use By Month (previous 2 academic years)',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      series_breakdown: :none,
      x_axis:           :month,
      timescale:        [{:academicyear => 0}, {:academicyear => -1}],
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    thermostatic: {
      name:             'Thermostatic',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    cusum: {
      name:             'CUSUM',
      chart1_type:      :line,
      meter_definition: :allheat,
      series_breakdown: :cusum,
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    baseload: {
      name:             'Baseload kW',
      chart1_type:      :line,
      series_breakdown: :baseload,
      meter_definition: :allelectricity,
      x_axis:           :day,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line:  {
      name:             'Intraday',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{:year => 0}, {:year => -1}],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    }
=begin

    electricity_year:  {
      name:             'Electricity Use Over Last Few Years',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :year,
      fuel:             :electricity,
      y2_axis:          :temperature,
      yaxis_units:      :£
    },
    electricity_acyear:  {
      name:             'Electricity Use Over Last Few Academic Years',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :academicyear,
      fuel:             :electricity,
      yaxis_units:      :£
    },
    group_by_week_electric: {
      name:             'By Week Electric',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :week,
      fuel:             :electricity,
      yaxis_units:      :£
    },
    day_of_week:  {
      name:             'Energy Use by Day of Week',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      meter_definition: :allelectricity,
      timescale:        :academicyear,
      yaxis_units:      :£,
      yaxis_scaling:    :per_200_pupils
    },
    group_by_month: {
      name:             'By Month',
      meter_definition: :allheat,
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :month,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      timescale:        :year,
      y2_axis:          :degreedays
    },
    group_by_month_2_schools: {
      schools:          ['St Johns Primary', 'Castle Primary School'],
      name:             'By Month',
      meter_definition: :allheat,
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :month,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      timescale:        :year,
      y2_axis:          :degreedays
    },
    day: {
      name:             'By Day',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      series_breakdown: :daytype,
      x_axis:           :day,
      yaxis_units:      :£,
      y2_axis:          :degreedays
    },
    last_week_by_day: {
      name:             'Last Week By Day',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      meter_definition: :all,
      series_breakdown: :fuel,
      x_axis:           :day,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      timescale:        [{:week => 0}, {:week => -1}, {:week => -2}], # , # , {:week => -1} {:week => -1}, # {:week => Date.new(2012, 11, 12)},
      y2_axis:          :degreedays
    },
    baseload: {
      name:             'By Day',
      chart1_type:      :line,
      series_breakdown: :baseload,
      fuel:             :electricity,
      x_axis:           :day,
      yaxis_units:      :kwh
    },
    thermostatic: {
      name:             'Thermostatic',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh
    },
    cusum: {
      name:             'CUSUM',
      chart1_type:      :line,
      series_breakdown: :cusum_heating,
      x_axis:           :day,
      yaxis_units:      :kwh
    },
    hotwater: {
      name:             'Hot Water',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :hotwater,
      x_axis:           :day,
      yaxis_units:      :kwh
    },
    intraday_line:  {
      name:             'Intraday',
      chart1_type:      :line,
      series_breakdown: :none,
      x_axis:           :intraday,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    }
    # rubocop:enable Style/HashSyntax, Layout/SpaceInsideHashLiteralBraces
=end
  }
  # rubocop:enable Style/ClassVars, Style/SymbolArray

  def initialize(school)
    @school = school
  end

  def run_standard_charts
    chart_definitions = []
    @@standard_charts.each do |chart_param|
      chart_definitions.push(run_standard_chart(chart_param))
    end
    chart_definitions
  end

  def run_standard_chart(chart_param)
    chart_config = @@standard_chart_configuration[chart_param]
    chart_definition = run_chart(chart_config)
    chart_definition
  end

  def run_chart(chart_config)
    # puts 'Chart configuration:'
    ap(chart_config, limit: 20, color: { float: :red })

    begin
      aggregator = Aggregator.new(@school, chart_config)

      # rubocop:disable Lint/AmbiguousBlockAssociation
      puts Benchmark.measure { aggregator.aggregate }
      # rubocop:enable Lint/AmbiguousBlockAssociation

      graph_data = configure_graph(aggregator, chart_config)

      graph_data
    rescue StandardError => e
      puts "Unable to create chart", e
      puts e.backtrace
      nil
    end
  end

  def configure_graph(aggregator, chart_config)
    graph_definition = {}

    graph_definition[:title]          = chart_config[:name] + ' ' + aggregator.title_summary

    graph_definition[:x_axis]         = aggregator.x_axis
    graph_definition[:x_data]         = aggregator.bucketed_data
    graph_definition[:chart1_type]    = chart_config[:chart1_type]
    graph_definition[:chart1_subtype] = chart_config[:chart1_subtype]
    # graph_definition[:yaxis_units]    = chart_config[:yaxis_units]
    # graph_definition[:yaxis_scaling]  = chart_config[:yaxis_scaling]
    graph_definition[:y_axis_label]   = chart_config[:y_axis_label]

    if chart_config.key?(:y2_axis)
      graph_definition[:y2_chart_type] = :line
      graph_definition[:y2_data] = aggregator.y2_axis
    end
    if !aggregator.data_labels.nil?
      graph_definition[:data_labels] = aggregator.data_labels
    end
    graph_definition
  end
end
