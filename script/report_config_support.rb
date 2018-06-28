# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

class DashboardReports
  def initialize
    @dashboard_page_groups = {  # dashboard page groups: defined page, and charts on that page
      main_dashboard_electric:  {
                                  name:   'Main Dashboard',
                                  charts: %i[
                                    benchmark
                                    daytype_breakdown_electricity
                                    group_by_week_electricity
                                  ]
                                },
      electricity_detail:      {
                                  name:   'Electricity Detail',
                                  charts: %i[
                                    daytype_breakdown_electricity
                                    group_by_week_electricity
                                    electricity_by_day_of_week
                                    baseload
                                    electricity_by_month_year_0_1
                                    intraday_line_school_days
                                    intraday_line_holidays
                                    intraday_line_weekends
                                    intraday_line_school_days_last5weeks
                                    intraday_line_school_days_6months
                                    intraday_line_school_last7days
                                    baseload_lastyear
                                  ]
                                },
      gas_detail:               {
                                  name:   'Gas Detail',
                                  charts: %i[
                                    daytype_breakdown_gas
                                    group_by_week_gas
                                    gas_by_day_of_week
                                  ]
                                },
      main_dashboard_electric_and_gas: {
                                  name:   'Main Dashboard',
                                  charts: %i[
                                    benchmark
                                    daytype_breakdown_electricity
                                    daytype_breakdown_gas
                                    group_by_week_electricity
                                    group_by_week_gas
                                  ]
                                },
      boiler_control:           {
                                  name: 'Advanced Boiler Control',
                                  charts: %i[
                                    group_by_week_gas
                                    frost_1
                                    frost_2
                                    frost_3
                                    thermostatic
                                    cusum
                                    thermostatic_control_large_diurnal_range_1
                                    thermostatic_control_large_diurnal_range_2
                                    thermostatic_control_large_diurnal_range_3
                                    thermostatic_control_medium_diurnal_range
                                    optimum_start
                                    hotwater
                                  ]
                                },
      simulator:                {
                                  name:   'Simulator Test',
                                  charts: %i[
                                    group_by_week_electricity_dd
                                    group_by_week_electricity_simulator_daytype
                                    group_by_week_electricity_simulator_appliance
                                    electricity_simulator_pie
                                    intraday_line_school_days_6months_simulator
                                    intraday_line_school_days_6months
                                    intraday_line_school_days_6months_simulator_submeters
                                  ]
                                }
    }

    @school_report_groups = { # 2 main dashboards: 1 for electric only schools, one for electric and gas schools
      electric_only:
                          %i[ 
                              main_dashboard_electric
                              electricity_detail
                          ],
      electric_and_gas:
                          %i[ 
                              main_dashboard_electric_and_gas
                              electricity_detail
                              gas_detail
                              boiler_control
                          ]
    }

    @schools = {
      'Bishop Sutton Primary School'      => :electric_and_gas,
      'Castle Primary School'             => :electric_and_gas,
      'Freshford C of E Primary'          => :electric_and_gas,
      'Marksbury C of E Primary School'   => :electric_only,
      'Paulton Junior School'             => :electric_and_gas,
      'Pensford Primary'                  => :electric_only,
      'Roundhill School'                  => :electric_and_gas,
      'Saltford C of E Primary School'    => :electric_and_gas,
      'St Johns Primary'                  => :electric_and_gas,
      'Stanton Drew Primary School'       => :electric_only,
      'Twerton Infant School'             => :electric_and_gas,
      'Westfield Primary'                 => :electric_and_gas
    }
    @benchmarks = []

    ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
    ENV['School Dashboard Advice'] = 'Include Header and Body'
    $SCHOOL_FACTORY = SchoolFactory.new

    @chart_manager = nil

    puts "\n" * 8
  end

  def self.suppress_output
    begin
      original_stdout = $stdout.clone
      $stdout.reopen(File.new('./Results/suppressed_log.txt', 'w'))
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

  def load_school(school_name, suppress_debug = false)
    puts self.class.banner("School: #{school_name}")
    @school_name = school_name
    if suppress_debug
      puts 'Loading school data.....output suppressed'
      self.class.suppress_output {
        @school = $SCHOOL_FACTORY.load_school(school_name)
      }
    else
      @school = $SCHOOL_FACTORY.load_school(school_name)
    end
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
    report_groups = @school_report_groups[report_config]

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
    page_config = @dashboard_page_groups[page_config_name]
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
    puts self.class.banner("Running report page  #{page_name}")
    @worksheet_charts[page_name] = []
    list_of_charts.each do |chart_name|
      chart = do_one_chart_internal(chart_name)
      unless chart.nil?
        @worksheet_charts[page_name].push(chart)
      end
    end
  end

  def do_one_chart_internal(chart_name)
    puts self.class.banner(chart_name.to_s)
    chart = nil
    bm = Benchmark.measure {
      chart = @chart_manager.run_standard_chart(chart_name)
    }
    @benchmarks.push(sprintf("%40.40s = %s", chart_name, bm.to_s))
    ap(chart, limit: 20, color: { float: :red })
    chart
  end
end
