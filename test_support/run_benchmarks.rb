require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

class RunBenchmarks
  attr_reader :control
  def initialize(control, schools)
    @control = control
    ap control
    puts "School list: #{schools}"
    @school_list = AnalysticsSchoolAndMeterMetaData.new.match_school_names(schools)
    @database = BenchmarkDatabase.new(control[:filename])
  end

  def run
    run_alerts_to_update_database if control.key?(:calculate_and_save_variables) && control[:calculate_and_save_variables]
    run_charts_and_tables(control[:run_charts_and_tables]) if control.key?(:run_charts_and_tables)
  end

  private

  def run_alerts_to_update_database
    @school_list.sort.each do |school_name|
      school = load_school(school_name)
      control[:asof_dates].each do |asof_date|
        calculate_alerts(school, asof_date)
      end
    end

    @database.save_database
  end

  def run_charts_and_tables(asof_date)
    benchmarks = Benchmarking::BenchmarkManager.new(@database.database)

    charts = []
    html = '<link rel="stylesheet" media="screen" href="https://fonts.googleapis.com/css?family=Open+Sans|Quicksand:300,500,700&amp;display=swap" />
    <link rel="stylesheet" media="all" href="https://cdn.energysparks.uk/static-assets/application-f2535905cd7274d6e4ffd9b4614323b1e11bbe6445bca5828b642a18516b9160.css" />'

    Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG.each do |chart_table_name, definition|
      if definition[:type].include?(:table)
        table = benchmarks.run_benchmark_table(asof_date, chart_table_name, nil) 
        html += "<h2>#{definition[:name]}</h2>"
        html += html_table(definition, table)
      end

      if definition[:type].include?(:chart)
        chart = benchmarks.run_benchmark_chart(asof_date, chart_table_name, nil)
        charts.push(chart)
      end
    end

    save_html(html)
    save_charts_to_excel(charts)
  end

  def html_table(table_definition, rows)
    header = table_definition[:columns].map{ |column_definition| column_definition[:name] }
    formatted_rows = format_rows(rows, table_definition[:columns])
    HtmlTableFormatting.new(header, formatted_rows).html
  end

  def format_rows(rows, column_definitions)
    column_units = column_definitions.map{ |column_definition| column_definition[:units] }
    formatted_rows = rows.map do |row|
      row.each_with_index.map do |value, index|
        column_units[index] == String ? value : FormatEnergyUnit.format(column_units[index], value, :html, false, true, :ks2)
      end
    end
  end

  def save_html(html)
    html_writer = HtmlFileWriter.new('benchmark')
    html_writer.write(html)
    html_writer.close
  end

  def save_charts_to_excel(charts)
    worksheets = { 'Test' => charts }
    excel_filename = File.join(File.dirname(__FILE__), '../Results/benchmark' + '.xlsx')
    excel = ExcelCharts.new(excel_filename)
    worksheets.each do |worksheet_name, charts|
      excel.add_charts(worksheet_name, charts.compact)
    end
    excel.close
  end

  def load_school(school_name)
    school_factory.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)
  end

  def school_factory
    $SCHOOL_FACTORY ||= SchoolFactory.new
  end

  def calculate_alerts(school, asof_date)
    puts "Calculating alerts for #{school.name} #{asof_date}"
    AlertAnalysisBase.all_available_alerts.each do |alert_class|
      alert = alert_class.new(school)
      next if alert_class.benchmark_template_variables.empty?
      next unless alert.valid_alert?

      alert.analyse(asof_date, true)
      puts "#{alert_class.name} failed" unless alert.calculation_worked
      next if !alert.make_available_to_users?

      save_benchmark_template_data(alert_class, alert, asof_date, school)
    end
  end

  def save_benchmark_template_data(alert_class, alert, asof_date, school)
    new_data = alert.benchmark_template_data
    alert_short_code = alert_class.short_code
    new_data.each do |key, value|
      variable_short_code = alert_class.benchmark_template_variables[key][:benchmark_code]
      @database.add_value(asof_date, school.urn, alert_short_code, variable_short_code, value)
    end
  end
end