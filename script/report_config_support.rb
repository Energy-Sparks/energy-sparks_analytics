# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

class ReportConfigSupport
  include Logging
  attr_reader :schools
  def initialize

    # @dashboard_page_groups = now in lib/dashboard/charting_and_reports/dashboard_configuration.rb
    # @school_report_groups = { # 2 main dashboards: 1 for electric only schools, one for electric and gas schools

    @schools = {
      'Bishop Sutton Primary School'      => :electric_and_gas,
      'Castle Primary School'             => :electric_and_gas,
      'Freshford C of E Primary'          => :electric_and_gas,
      'Marksbury C of E Primary School'   => :electric_only,
      'Paulton Junior School'             => :electric_and_gas,
      'Pensford Primary'                  => :electric_only,
      'Roundhill School'                  => :electric_and_gas,
      'Saltford C of E Primary School'    => :electric_and_gas,
      'St Marks Secondary'                => :electric_and_gas,
      'St Johns Primary'                  => :electric_and_gas,
      'St Saviours Junior'                => :electric_and_gas,
      'Stanton Drew Primary School'       => :electric_only,
      'Trinity First School'              => :electric_and_gas,
      'Twerton Infant School'             => :electric_and_gas,
      'Westfield Primary'                 => :electric_and_gas
    }
    @benchmarks = []

    ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
    ENV['School Dashboard Advice'] = 'Include Header and Body'
    $SCHOOL_FACTORY = SchoolFactory.new

    @chart_manager = nil

    logger.debug "\n" * 8
  end

  def self.suppress_output(school_name)
    begin
      original_stdout = $stdout.clone
      $stdout.reopen(File.new('./Results/' + school_name + 'loading log.txt', 'w'))
      retval = yield
    rescue StandardError => e
      $stdout.reopen(original_stdout)
      raise e
    ensure
      $stdout.reopen(original_stdout)
    end
    retval
  end

  def do_all_schools(suppress_debug = false)
    @schools.keys.each do |school_name|
      load_school(school_name, suppress_debug)
      do_all_standard_pages_for_school
    end
  end

  def self.banner(title)
    cols = 120
    len_before = ((cols - title.length) / 2).floor
    len_after = cols - title.length - len_before
    '=' * len_before + title + '=' * len_after
  end

  def setup_school(school, school_name)
    @school_name = school_name
    @school = school
    @chart_manager = ChartManager.new(@school)
  end

  def load_school(school_name, suppress_debug = false)
    logger.debug self.class.banner("School: #{school_name}")

    @school_name = school_name

    school_metadata = AnalysticsSchoolAndMeterMetaData.new
    @school = school_metadata.school(school_name)

    readings_db = LocalAnalyticsMeterReadingDB.new(@school)
    readings_db.load_meter_readings

    @chart_manager = ChartManager.new(@school)
    @school # needed to run simulator
  end

  def report_benchmarks
    @benchmarks.each do |bm|
      puts bm
    end
    @benchmarks = []
  end

  def do_all_standard_pages_for_school
    @worksheet_charts = {}

    report_config = @schools[@school_name]
    report_groups = DashboardConfiguration::DASHBOARD_FUEL_TYPES[report_config]

    report_groups.each do |report_page|
      do_one_page(report_page, false)
    end

    save_excel_and_html
  end

  def save_excel_and_html
    write_excel
    write_html
  end

  def do_one_page(page_config_name, reset_worksheets = true)
    @worksheet_charts = {} if reset_worksheets
    page_config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[page_config_name]
    do_one_page_internal(page_config[:name], page_config[:charts])
  end

  def do_chart_list(page_name, list_of_charts)
    @worksheet_charts = {}
    do_one_page_internal(page_name, list_of_charts)
  end

  def write_excel
    excel = ExcelCharts.new(File.join(File.dirname(__FILE__), '../Results/') + @school_name + '- charts test.xlsx')
    @worksheet_charts.each do |worksheet_name, charts|
      excel.add_charts(worksheet_name, charts)
    end
    excel.close
  end

  def write_html
    html_file = HtmlFileWriter.new(@school_name)
    @worksheet_charts.each do |worksheet_name, charts|
      html_file.write_header(worksheet_name)
      charts.each do |chart|
        html_file.write_header_footer(chart[:config_name], chart[:advice_header], chart[:advice_footer])
      end
    end
    html_file.close
  end

  def do_one_page_internal(page_name, list_of_charts)
    logger.debug self.class.banner("Running report page  #{page_name}")
    @worksheet_charts[page_name] = []
    list_of_charts.each do |chart_name|
      charts = do_charts_internal(chart_name)
      unless charts.nil?
        charts.each do |chart|
          ap(chart, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
          @worksheet_charts[page_name].push(chart)
        end
      end
    end
  end

  def do_charts_internal(chart_name)
    if chart_name.is_a?(Symbol)
      logger.debug self.class.banner(chart_name.to_s)
    else
      logger.debug "Running Composite Chart #{chart_name[:name]}"
    end
    chart_results = nil
    puts "Chart: #{chart_name}"
    bm = Benchmark.measure {
      chart_results = @chart_manager.run_chart_group(chart_name)
    }
    @benchmarks.push(sprintf("%40.40s = %s", chart_name, bm.to_s))
    
    if chart_name.is_a?(Symbol)
      [chart_results]
    else
      chart_results[:charts]
    end
  end
end
