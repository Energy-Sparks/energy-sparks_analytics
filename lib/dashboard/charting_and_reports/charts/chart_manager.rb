# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  class ChartInheritanceConfigurationTooDeep < StandardError; end
  include Logging

  attr_reader :school

  def initialize(school, show_reconciliation_values = true)
    @school = school
    @show_reconciliation_values = show_reconciliation_values
  end

  def run_chart_group(chart_param, override_config = nil, reraise_exception = false)
    if chart_param.is_a?(Symbol)
      run_standard_chart(chart_param, override_config, reraise_exception)
    elsif chart_param.is_a?(Hash)
      run_composite_chart(chart_param, override_config, reraise_exception)
    end
  end

  def run_composite_chart(chart_group, override_config = nil, reraise_exception = false)
    logger.info "Running composite chart group #{chart_group[:name]}"
    chart_group_result = {}
    chart_group_result[:config] = chart_group
    chart_group_result[:charts] = []
    chart_group[:chart_group][:charts].each do |chart_param|
      chart = run_standard_chart(chart_param, override_config, reraise_exception)
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

  #Recursively build up complete chart config from the inheritance tree
  #Does not resolve any data specific chart options, e.g. x axis groupings
  def self.build_chart_config(chart_config_original, max_inheritance = 20)
    chart_config = chart_config_original.dup
    while chart_config.key?(:inherits_from)
      base_chart_config_param = chart_config[:inherits_from]
      base_chart_config = standard_chart(base_chart_config_param).dup
      chart_config.delete(:inherits_from)
      chart_config = base_chart_config.merge(chart_config)
      max_inheritance -= 1
      if max_inheritance == 0
        logger.error "Chart inheritance too deep for #{chart_config_original}"
        unless Object.const_defined?('Rails')
          puts 'Chart inheritance too deep for'
          ap chart_config_original
        end
        raise ChartInheritanceConfigurationTooDeep, "Inheritance too deep for #{chart_config_original}"
      end
    end
    chart_config
  end

  # recursively inherit previous chart definitions config, then resolve x-axis against available data
  def resolve_chart_inheritance(chart_config_original, max_inheritance = 20)
    chart_config = self.class.build_chart_config(chart_config_original, max_inheritance)
    resolve_x_axis_grouping(chart_config)
  end

  # Used by ES Web application
  def run_standard_chart(chart_param, override_config = nil, reraise_exception = false)
    chart_config = get_chart_config(chart_param, override_config)
    chart_definition = run_chart(chart_config, chart_param, false, override_config, reraise_exception)
    chart_definition
  end

  # Used by ES Web application
  def get_chart_config(chart_param, override_config = nil)
    resolved_chart = resolve_chart_inheritance(self.class.standard_chart(chart_param))
    resolved_chart.merge!(override_config) unless override_config.nil?
    resolved_chart
  end

  # Used by ES Web application
  def run_chart(chart_config, chart_param, resolve_inheritance = true, override_config = nil, reraise_exception = false)
    logger.info '>' * 120
    logger.info chart_config[:name]
    logger.info '>' * 120

    chart_config = resolve_chart_inheritance(chart_config) if resolve_inheritance
    chart_config = resolve_x_axis_grouping(chart_config) unless resolve_inheritance #dont do it twice

    # overrides standard chart config, for example if you want to override
    # the default meter if providing charts at meter rather than aggregate level
    chart_config.merge!(override_config) unless override_config.nil?

    ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    begin
      aggregator = nil
      calculation_time = nil

      RecordTestTimes.instance.record_time(@school.name, 'chart', chart_param){
        calculation_time = Benchmark.realtime {
          aggregator = Aggregator.new(@school, chart_config, @show_reconciliation_values)

          aggregator.aggregate
        }
      }

      if aggregator.valid
        graph_data = configure_graph(aggregator, chart_config, chart_param, calculation_time)

        ap(graph_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
        logger.info '<' * 120

        graph_data
      else
        nil
      end
    rescue StandardError => e
      puts e
      puts e.backtrace
      logger.warn "Unable to create chart"
      if reraise_exception
        raise
      else
#LD(2021-04-29) These calls are causing the Rails app to hang. Any call to
#print or inspect the exception or stack trace cause a CPU spike and a hang
#A Ctrl-C clears and execution continues. There's some issue with the Rails logger
#and/or the exceptions raised here that are causing a problem. Needs further
#investigation. But in testing these exceptions were all NoMethodError so
#shouldn't really be caught here.
#
        # PH(12Nov2021) - bug code back in just for analytics to aid debugging
        if !Object.const_defined?('Rails')
          logger.info e.message
          logger.info e.backtrace
        end

        nil
      end
    end
  end

  def configure_graph(aggregator, chart_config, chart_param, calculation_time)
    graph_definition = {}

    graph_definition[:title]          = chart_config[:name] # + ' ' + aggregator.title_summary

    graph_definition[:x_axis]         = aggregator.x_axis
    graph_definition[:x_axis_ranges]  = aggregator.x_axis_bucket_date_ranges
    graph_definition[:x_data]         = aggregator.bucketed_data
    graph_definition[:x_axis_label]   = aggregator.x_axis_label unless aggregator.x_axis_label.nil?
    graph_definition[:chart1_type]    = chart_config[:chart1_type]
    graph_definition[:chart1_subtype] = chart_config[:chart1_subtype]
    graph_definition[:y_axis_label]   = chart_config[:y_axis_label]
    graph_definition[:config_name]    = chart_param
    graph_definition[:data_labels]    = aggregator.data_labels unless aggregator.data_labels.nil?
    graph_definition[:subtitle]       = aggregator.subtitle unless aggregator.subtitle.nil?

    graph_definition[:multi_chart_x_axis_ranges] = aggregator.multi_chart_x_axis_ranges

    if aggregator.y2_axis?
      graph_definition[:y2_chart_type] = :line
      graph_definition[:y2_data] = aggregator.y2_axis
    end

    graph_definition[:configuration] = chart_config
    graph_definition[:name] = chart_param

    advice = DashboardChartAdviceBase.advice_factory(chart_param, @school, chart_config, graph_definition, chart_param)

    unless advice.nil?
      advice.generate_advice
      graph_definition[:advice_header] = advice.header_advice
      graph_definition[:advice_footer] = advice.footer_advice
    end
    # ap(graph_definition, limit: 20)
    graph_definition[:calculation_time] = calculation_time

    graph_definition
  end

  private

  def self.standard_chart(chart_name)
    STANDARD_CHART_CONFIGURATION[chart_name]
  end

  def resolve_x_axis_grouping(chart_config)
    if ChartDynamicXAxis.is_dynamic?(chart_config)
      ChartDynamicXAxis.new(@school, chart_config).redefined_chart_config
    else
      chart_config
    end
  end
end
