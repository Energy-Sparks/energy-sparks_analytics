module Benchmarking
  class BenchmarkContentBase
    attr_reader :benchmark_manager, :asof_date, :page_name, :chart_table_config
    def initialize(benchmark_database, asof_date, page_name, chart_table_config)
      @benchmark_manager = BenchmarkManager.new(benchmark_database)
      @asof_date = asof_date
      @page_name = page_name
      @chart_table_config = chart_table_config
    end

    def front_end_content(school_ids: nil, filter: nil)
      content(school_ids, filter).select{ |content_config| %i[html chart_name chart table title].include?(content_config[:type]) }
    end

    def content(school_ids: nil, filter: nil)
      chart       = run_chart(school_ids, filter)         if charts?
      table_html  = run_table(school_ids, filter, :html)  if tables?
      table_text  = run_table(school_ids, filter, :text)  if tables?
      composite   = run_table(school_ids, filter, :text_and_raw) if tables?

      charts = charts? ? [
        { type: :html,                  content: chart_introduction_text },
        { type: :chart_name,            content: chart_name },
        { type: :chart,                 content: chart },
        { type: :html,                  content: chart_interpretation_text }
      ] : nil

      tables = tables? ? [
        { type: :html,                  content: table_introduction_text},
        { type: :table_html,            content: table_html },
        { type: :table_text,            content: table_text },
        { type: :table_composite,       content: composite },
        { type: :html,                  content: table_interpretation_text }
      ] : nil

      caveats = [{ type: :html,         content: caveat_text}]

      [preamble_content, charts, tables, caveats].compact.flatten
    end

    protected def preamble_content
      [
        { type: :analytics_html,        content: '<br>' },
        # { type: :html,                  content: content_title },
        { type: :title,                 content: chart_table_config[:name]},
        { type: :html,                  content: introduction_text },
      ]
    end

    protected def content_title
      text = %( <h1><%= chart_table_config[:name] %></h1> )
      ERB.new(text).result(binding)
    end

    protected def introduction_text
      %q( <h3>Introduction here</h3> )
    end

    protected def introduction_text
      %q( <h3>Introduction here</h3> )
    end

    protected def chart_introduction_text
      %q( <h3>Chart Introduction</h3> )
    end

    protected def chart_interpretation_text
      %q( <h3>Chart interpretation</h3> )
    end

    protected def table_introduction_text
      %q( <h3>Table Introduction</h3> )
    end

    protected def table_interpretation_text
      %q( <h3>Table interpretation</h3> )
    end

    protected def caveat_text
      %q( <h3>Caveat</h3> )
    end

    def charts?
      chart_table_config[:type].include?(:chart)
    end

    def tables?
      chart_table_config[:type].include?(:table)
    end

    def chart_name
      page_name
    end
  
    def run_chart(school_ids, filter)
      benchmark_manager.run_benchmark_chart(asof_date, page_name, school_ids, nil, filter)
    end
  
    def run_table(school_ids, filter, medium)
      benchmark_manager.run_benchmark_table(asof_date, page_name, school_ids, nil, filter, medium)
    end
  end
end
