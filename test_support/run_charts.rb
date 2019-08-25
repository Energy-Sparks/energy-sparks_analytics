# runs charts and advice and outputs html and Excel files
class RunCharts
  include Logging

  attr_reader :failed_charts

  def initialize(school)
    @school = school
    @worksheets = Hash.new { |worksheet_name, charts| worksheet_name[charts] = [] }
    @excel_filename = File.join(File.dirname(__FILE__), '../Results/') + @school.name + '- charts test.xlsx'
    @runtime = Time.now.strftime('%d/%m/%Y %H:%M:%S')
    @failed_charts = []
  end

  def run(charts, control)
    charts = [charts] unless charts.is_a?(Array)
    charts.each do |config_component|
      run_config_component(config_component)
    end
    save_to_excel
    write_html
    save_chart_calculation_times
    report_calculation_time(control)
    CompareChartResults.new(control[:compare_results], @school.name).compare_results(all_charts)
    log_results
  end

  def self.report_failed_charts(failed_charts, detail)
    puts 'Failed Charts:'
    failed_charts.each do |failed_chart|
      short_backtrace = failed_chart[:backtrace][0].split('/').last
      puts sprintf('%-15.15s %-25.25s %-35.35s %-80.80s %-20.20s', 
        failed_chart[:school_name], failed_chart[:chart_name], failed_chart[:message], short_backtrace, failed_chart[:type])
      puts failed_chart[:backtrace] if detail == :detailed
    end
  end

  private

  def report_calculation_time(control)
    puts "Average calculation rate #{average_calculation_rate.round(1)} charts per second" if control.key?(:display_average_calculation_rate)
  end

  def log_results
    failed = @failed_charts.nil? ? -1 : @failed_charts.length
    charts = number_of_charts.nil? ? 0 : number_of_charts
    calc_time = total_chart_calculation_time.nil? ? 0.0 : total_chart_calculation_time
    puts sprintf('Completed %2d charts for %-25.25s %d failed in %.3fs', charts, @school.name, failed, calc_time)
  end

  def number_of_charts
    @worksheets.map { |worksheet, charts| charts.length}.sum
  end

  def total_chart_calculation_time
    @worksheets.map { |worksheet, charts| charts.map { |chart| chart[:calculation_time] }.sum }.sum
  end

  def run_config_component(config_component)
    if config_component.is_a?(Symbol) && config_component == :dashboard
      run_dashboard
    elsif config_component.is_a?(Hash) && config_component.keys[0] == :adhoc_worksheet
      run_single_dashboard_page(config_component.values[0])
    end
  end

  def run_dashboard
    logger.info "Running dashboard charts for #{@school.name} dashboard type #{@school.report_group}"
    logger.info "Dashboard type #{@school.report_group}"

    report_groups = DashboardConfiguration::DASHBOARD_FUEL_TYPES[@school.report_group]

    report_groups.each do |page_name|
      run_single_dashboard_page(DashboardConfiguration::DASHBOARD_PAGE_GROUPS[page_name])
    end
  end

  def run_single_dashboard_page(single_page_config)
    logger.info "    Doing page #{single_page_config[:name]}"
    logger.info "        Charts #{single_page_config[:charts].join(';')}"
    single_page_config[:charts].each do |chart_name|
      run_chart(single_page_config[:name], chart_name)
    end
  end

  def run_chart(page_name, chart_name)
    logger.info "            #{chart_name}"
    chart_manager = ChartManager.new(@school)
    begin
      chart_results = chart_manager.run_chart_group(chart_name, nil, true) # chart_override)
      if chart_results.nil?
        @failed_charts.push( { school_name: @school.name, chart_name: chart_name, message: 'Unknown', backtrace: nil } )
        nil
      else
        chart_results = [chart_results] unless chart_results.is_a?(Array)
        @worksheets[page_name] += chart_results.flatten # could be a composite chart
      end
    rescue => e
      @failed_charts.push( { school_name: @school.name, chart_name: chart_name,  message: e.message, backtrace: e.backtrace, type: e.class.name } )
      nil
    end
  end

  def save_to_excel
    excel = ExcelCharts.new(@excel_filename)
    @worksheets.each do |worksheet_name, charts|
      excel.add_charts(worksheet_name, charts.compact)
    end
    excel.close
  end

  def save_chart_calculation_times
    File.open(TestDirectoryConfiguration::BENCHMARKFILENAME, 'a') do |file|
      @worksheets.each_value do |charts|
        charts.each do |chart|
          data = [
            @school.name,
            chart[:name],
            @runtime,
            chart[:calculation_time]
          ]
          file.puts data.join(',')
        end
      end
    end
  end

  def average_calculation_time
    all_times = @worksheets.values.map { |charts| charts.map { |chart| chart[:calculation_time] } }.flatten
    return Float::NAN if all_times.empty?
    all_times.sum / all_times.length
  end

  def average_calculation_rate
    1.0 / average_calculation_time
  end

  def all_charts
    @worksheets.values.flatten
  end

  def write_html
    html_file = HtmlFileWriter.new(@school.name)
    @worksheets.each do |worksheet_name, charts|
      html_file.write_header(worksheet_name)
      charts.compact.each do |chart|
        html_file.write_header_footer(chart[:config_name], chart[:advice_header], chart[:advice_footer])
      end
    end
    html_file.close
  end
end
