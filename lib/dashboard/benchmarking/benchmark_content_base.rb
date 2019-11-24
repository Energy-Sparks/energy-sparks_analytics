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
        { type: :html,                  content: "<h3>Chart Introduction</h3>" },
        { type: :chart_name,            content: chart_name },
        { type: :chart,                 content: chart },
        { type: :html,                  content: "<h3>Chart Interpretation</h3>" }
      ] : nil

      tables = tables? ? [
        { type: :html,                  content: "<h3>Table Introduction</h3>"},
        { type: :table_html,            content: table_html },
        { type: :table_text,            content: table_text },
        { type: :table_composite,       content: composite },
        { type: :html,                  content: "<h3>Table Interpretation</h3>" }
      ] : nil

      caveats = [{ type: :html,         content: "<h3>Caveat</h3>"}]

      [preamble_content, charts, tables, caveats].compact.flatten
    end

    protected def preamble_content
      [
        { type: :analytics_html,        content: '<br>' },
        { type: :html,                  content: "<h1>#{chart_table_config[:name]}</h1>" },
        { type: :title,                 content: chart_table_config[:name]},
        { type: :html,                  content: introduction_text },
      ]
    end

    protected def introduction_text
      %q( <h3>Introduction here</h3> )
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

  class BenchmarkContentElectricityPerPupil < BenchmarkContentBase
    private def introduction_text
      %q(
        <p>
          This benchmark compares the electricity consumed per pupil each year,
          expressed in pounds.
        </p>
        <p>
          A realistic target for the primary school to use less than
          &pound;20 per pupil per year, for middle schools &pound;30
          and for secondaries &pound;40. 
        </p>
      )
    end
  end
end
