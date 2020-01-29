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

    def content(school_ids: nil, filter: nil, user_type: nil)
      charts = nil
      tables = nil
      caveats = nil

      chart       = run_chart(school_ids, filter, user_type)                if charts?
      table_html  = run_table(school_ids, filter, :html, user_type)         if tables?
      table_text  = run_table(school_ids, filter, :text, user_type)         if tables?
      composite   = run_table(school_ids, filter, :text_and_raw, user_type) if tables?

      if (tables? || charts?) && table_text[:rows].empty?
        tables = { type: :html, content: '<h3>There are no schools to report using this filter for this benchmark</h3>' }
      else
        charts = [
          { type: :html,                  content: chart_introduction_text },
          { type: :chart_name,            content: chart_name },
          { type: :chart,                 content: chart },
          { type: :html,                  content: chart_interpretation_text }
        ] if charts? && !chart_empty?(chart)

        tables = [
          { type: :html,                  content: table_introduction_text},
          { type: :table_html,            content: table_html },
          { type: :table_text,            content: table_text },
          { type: :table_composite,       content: composite },
          { type: :html,                  content: table_interpretation_text }
        ] if tables?

        caveats = [{ type: :html,         content: caveat_text}]
      end 

      [preamble_content, charts, tables, caveats, drilldown(school_ids, user_type)].compact.flatten
    end

    protected def preamble_content
      [
        { type: :analytics_html,        content: '<br>' },
        # { type: :html,                  content: content_title },
        { type: :title,                 content: chart_table_config[:name]},
        { type: :html,                  content: introduction_text },
      ]
    end

    private def drilldown(school_ids, user_type)
      drilldown_info = benchmark_manager.drilldown_class(@page_name)
      return nil if drilldown_info.nil?
      {
        type:     :drilldown,
        content:  {
                    drilldown:  drilldown_info,
                    school_map: school_map(school_ids, user_type)
                  }
      }
    end

    private def school_map(school_ids, user_type)
      schools = benchmark_manager.run_benchmark_table(asof_date, :school_information, school_ids, false, nil, :raw, user_type)
      schools.map { |school_data| {name: school_data[0], urn: school_data[1]} }
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

    def run_chart(school_ids, filter, user_type = nil)
      benchmark_manager.run_benchmark_chart(asof_date, page_name, school_ids, nil, filter, user_type)
    end

    def run_table(school_ids, filter, medium, user_type = nil)
      benchmark_manager.run_benchmark_table(asof_date, page_name, school_ids, nil, filter, medium, user_type)
    end

    def chart_empty?(chart_results)
      chart_results.nil? || !chart_results[:x_data].values.any?{ |data| !data.all?(&:nil?) }
    end
  end
end
