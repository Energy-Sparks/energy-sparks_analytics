# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  include Logging

  attr_reader :school

  def initialize(school, show_reconciliation_values = true)
    @school = school
    @show_reconciliation_values = show_reconciliation_values
  end

  def run_chart_group(chart_param, override_config = nil)
    if chart_param.is_a?(Symbol)
      run_standard_chart(chart_param, override_config)
    elsif chart_param.is_a?(Hash)
      run_composite_chart(chart_param, override_config = nil)
    end
  end

  def run_composite_chart(chart_group, override_config = nil)
    puts "Running composite chart group #{chart_group[:name]}"
    chart_group_result = {}
    chart_group_result[:config] = chart_group
    chart_group_result[:charts] = []
    chart_group[:chart_group][:charts].each do |chart_param|
      chart = run_standard_chart(chart_param, override_config = nil)
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

  # recursively inherit previous chart definitions config
  private def resolve_chart_inheritance(chart_config_original)
    chart_config = chart_config_original.dup
    while chart_config.key?(:inherits_from)
      base_chart_config_param = chart_config[:inherits_from]
      base_chart_config = STANDARD_CHART_CONFIGURATION[base_chart_config_param].dup
      chart_config.delete(:inherits_from)
      chart_config = base_chart_config.merge(chart_config)
    end
    chart_config
  end

  # Used by ES Web application
  def run_standard_chart(chart_param, override_config = nil)
    chart_config = get_chart_config(chart_param, override_config)
    chart_definition = run_chart(chart_config, chart_param, false, override_config)
    chart_definition
  end

  # Used by ES Web application
  def get_chart_config(chart_param, override_config = nil)
    resolved_chart = resolve_chart_inheritance(STANDARD_CHART_CONFIGURATION[chart_param])
    resolved_chart.merge!(override_config) unless override_config.nil?
    resolved_chart
  end

  # Used by ES Web application
  def run_chart(chart_config, chart_param, resolve_inheritance = true, override_config = nil)
    logger.info '>' * 120
    logger.info chart_config[:name]
    logger.info '>' * 120

    chart_config = resolve_chart_inheritance(chart_config) if resolve_inheritance

    # overrides standard chart config, for example if you want to override
    # the default meter if providing charts at meter rather than aggregate level
    chart_config.merge!(override_config) unless override_config.nil?

    ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    begin
      aggregator = Aggregator.new(@school, chart_config, @show_reconciliation_values)

      aggregator.aggregate

      if aggregator.valid
        graph_data = configure_graph(aggregator, chart_config, chart_param)

        ap(graph_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
        logger.info '<' * 120

        graph_data
      else
        nil
      end
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
    graph_definition[:y_axis_label]   = chart_config[:y_axis_label]
    graph_definition[:config_name]    = chart_param
    graph_definition[:data_labels]    = aggregator.data_labels unless aggregator.data_labels.nil?

    if chart_config.key?(:y2_axis) && !chart_config[:y2_axis].nil?
      graph_definition[:y2_chart_type] = :line
      graph_definition[:y2_data] = aggregator.y2_axis
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
