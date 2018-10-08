# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  include Logging

  attr_reader :school

  def initialize(school)
    @school = school
  end

=begin
# TODO(PH,7Oct2018) - remove if not used soon after
  def run_standard_charts
    chart_definitions = []
    STANDARD_CHARTS.each do |chart_param|
      chart_definitions.push(run_standard_chart(chart_param))
    end
    chart_definitions
  end
=end

  def run_chart_group(chart_param)
    if chart_param.is_a?(Symbol)
      run_standard_chart(chart_param)
    elsif chart_param.is_a?(Hash)
      run_composite_chart(chart_param)
    end
  end

  def run_composite_chart(chart_group)
    puts "Running composite chart group #{chart_group[:name]}"
    chart_group_result = {}
    chart_group_result[:config] = chart_group
    chart_group_result[:charts] = []
    chart_group[:chart_group][:charts].each do |chart_param|
      chart = run_standard_chart(chart_param)
      ap(chart, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
      chart_group_result[:charts].push(chart)
    end

    if chart_group[:advice_text]
      advice = DashboardChartAdviceBase.advice_factory_group(chart_group[:type], @school, chart_group, chart_group_result[:charts])

      unless advice.nil?
        advice.generate_advice
        chart_group_result[:advice_header] = advice.header_advice
        chart_group_result[:advice_footer] = advice.footer_advice
      end
    end

    ap(chart_group_result, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    chart_group_result
  end

  def drilldown(old_chart_name, chart_config_original, series_name, x_axis_range)
    

    chart_config = resolve_chart_inheritance(chart_config_original)

    if chart_config[:series_breakdown] == :baseload || 
       chart_config[:series_breakdown] == :cusum ||
       chart_config[:series_breakdown] == :hotwater ||
       chart_config[:chart1_type]      == :scatter
       # these special case may need reviewing if we decide to aggregate
       # these types of graphs by anything other than days
       # therefore create a single date datetime drilldown

       chart_config[:chart1_type] = :column
       chart_config[:series_breakdown] = :none
    else
      puts "Starting drilldown chart config:"
      ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

      chart_config.delete(:inject)

      unless series_name.nil?
        new_filter = drilldown_series_name(chart_config, series_name)
        chart_config = chart_config.merge(new_filter)
      end

      chart_config[:chart1_type] = :column if chart_config[:chart1_type] == :bar
    end

    unless x_axis_range.nil?
      new_timescale_x_axis = drilldown_daterange(chart_config, x_axis_range)
      chart_config = chart_config.merge(new_timescale_x_axis)
    end

    new_chart_name = (old_chart_name.to_s + '_drilldown').to_sym

    chart_config[:name] += (series_name.nil? && x_axis_range.nil?) ? ' no drilldown' : ' drilldown'

    puts "Final drilldown chart config: #{chart_config}"
    ap(chart_config, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    [new_chart_name, chart_config]
  end

  def drilldown_series_name(chart_config, series_name)
    existing_filter = chart_config.key?(:filter) ? chart_config[:filter] : {}
    existing_filter[chart_config[:series_breakdown]] = series_name
    new_filter = { filter: existing_filter }
  end

  def drilldown_daterange(chart_config, x_axis_range)
    new_x_axis = x_axis_drilldown(chart_config[:x_axis])
    if new_x_axis.nil?
      throw EnergySparksBadChartSpecification.new("Illegal drilldown requested for #{chart_config[:name]}  call drilldown_available first")
    end

    date_range_config = {
      timescale: { daterange: [x_axis_range[0], x_axis_range[1]]},
      x_axis: new_x_axis
    }
  end

  def drilldown_available(chart_config)
    !x_axis_drilldown(chart_config[:x_axis]).nil?
  end

  def x_axis_drilldown(existing_x_axis_config)
    case existing_x_axis_config
    when :year, :academicyear
      :week
    when :month, :week
      :day
    when :day
      :datetime
    when :datetime, :dayofweek, :intraday, :nodatebuckets
      nil
    else
      throw EnergySparksBadChartSpecification.new("Unhandled x_axis drilldown config #{existing_x_axis_config}")
    end
  end

  # recursively inherit previous chart definitions config
  def resolve_chart_inheritance(chart_config_original)
    chart_config = chart_config_original.dup
    while chart_config.key?(:inherits_from)
      base_chart_config_param = chart_config[:inherits_from]
      base_chart_config = STANDARD_CHART_CONFIGURATION[base_chart_config_param].dup
      chart_config.delete(:inherits_from)
      chart_config = base_chart_config.merge(chart_config)
    end
    chart_config
  end

  def run_standard_chart(chart_param)
    chart_config = resolve_chart_inheritance(STANDARD_CHART_CONFIGURATION[chart_param])
    chart_definition = run_chart(chart_config, chart_param)
    chart_definition
  end

  def run_chart(chart_config, chart_param)
    logger.info '>' * 120
    # puts 'Chart configuration:'
    ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    begin
      aggregator = Aggregator.new(@school, chart_config)

      aggregator.aggregate

      graph_data = configure_graph(aggregator, chart_config, chart_param)

      ap(graph_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
      
      logger.info '<' * 120

      graph_data
    rescue StandardError => e
      puts "Unable to create chart", e
      puts e.backtrace
      nil
    end
  end

  def configure_graph(aggregator, chart_config, chart_param)
    graph_definition = {}

    graph_definition[:title]          = chart_config[:name] + ' ' + aggregator.title_summary

    graph_definition[:x_axis]         = aggregator.x_axis
    graph_definition[:x_axis_ranges]  = aggregator.x_axis_bucket_date_ranges
    graph_definition[:x_data]         = aggregator.bucketed_data
    graph_definition[:chart1_type]    = chart_config[:chart1_type]
    graph_definition[:chart1_subtype] = chart_config[:chart1_subtype]
    # graph_definition[:yaxis_units]    = chart_config[:yaxis_units]
    # graph_definition[:yaxis_scaling]  = chart_config[:yaxis_scaling]
    graph_definition[:y_axis_label]   = chart_config[:y_axis_label]
    graph_definition[:config_name]    = chart_param

    if chart_config.key?(:y2_axis)
      graph_definition[:y2_chart_type] = :line
      graph_definition[:y2_data] = aggregator.y2_axis
    end
    if !aggregator.data_labels.nil?
      graph_definition[:data_labels] = aggregator.data_labels
    end

    graph_definition[:configuration] = chart_config

    advice = DashboardChartAdviceBase.advice_factory(chart_param, @school, chart_config, graph_definition, chart_param)

    unless advice.nil?
      advice.generate_advice
      graph_definition[:advice_header] = advice.header_advice
      graph_definition[:advice_footer] = advice.footer_advice
    end
    graph_definition
  end
end
