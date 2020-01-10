require_relative './logger_control.rb'
require_relative './test_directory_configuration.rb'
require 'ruby-prof'
$logger_format = 1

class RunTests
  include Logging
  include TestDirectoryConfiguration

  DEFAULT_TEST_SCRIPT = {
    logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
    # ruby_profiler:            true,
=begin
    dark_sky_temperatures:    nil,
    grid_carbon_intensity:    nil,
    sheffield_solar_pv:       nil,
=end
    schools:                  ['White.*', 'Trin.*', 'Round.*' ,'St John.*'],
    source:                   :analytics_db,
    logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
    drilldown: true,
    no_reports:                  {
                                charts: [
                                  :dashboard,
                                  # adhoc_worksheet: { name: 'Test', charts: [:gas_latest_years, :gas_by_day_of_week] }
                                ],
                                control: {
                                  display_average_calculation_rate: true,
                                  report_failed_charts:   :summary,
                                  compare_results:        [ :summary, :report_differing_charts, :report_differences ] # :quick_comparison,
                                }
                              }, 

    alerts:                   {
                                  alerts:   nil, # [ AlertOutOfHoursElectricityUsage ],
                                  control:  {
                                              # print_alert_banner: true,
                                              # alerts_history: true,
                                              print_school_name_banner: true,
                                              outputs:           %i[], # front_end_template_variables front_end_template_data raw_variables_for_saving],
                                              not_save_and_compare:  {
                                                                    summary:      true,
                                                                    h_diff:     { use_lcs: false, :numeric_tolerance => 0.000001 },
                                                                    data: %i[
                                                                      front_end_template_variables
                                                                      raw_variables_for_saving
                                                                      front_end_template_data
                                                                      front_end_template_chart_data
                                                                      front_end_template_table_data
                                                                    ]
                                                                  },

                                              save_priority_variables:  { filename: './TestResults/alert priorities.csv' },
                                              benchmark:          %i[school alert ], # detail],
                                              asof_date:          (Date.new(2018,6,14)..Date.new(2019,6,14)).each_slice(7).map(&:first)
                                            } 
                              }
  }.freeze

  def initialize(test_script = DEFAULT_TEST_SCRIPT)
    @test_script = test_script
    @log_filename = STDOUT
  end

  def run
    logger.info '=' * 120
    logger.info 'RUNNING TESTS:'
    logger.info '=' * 120

    @test_script.each do |component, configuration|
      case component
      when :dark_sky_temperatures
        update_dark_sky_temperatures
      when :grid_carbon_intensity
        update_grid_carbon_intensity
      when :sheffield_solar_pv
        update_sheffield_solar_pv
      when :schools
        determine_schools(configuration)
      when :source
        @meter_readings_source = configuration
      when :reports
        $logger_format = 2
        run_reports(configuration[:charts], configuration[:control])
      when :alerts
        run_alerts(configuration[:alerts], configuration[:control])
      when :drilldown
        run_drilldown
      when :timescales
        run_timescales
      when :timescale_and_drilldown
        run_timescales_drilldown
      when :pupil_dashboard
        run_pupil_dashboard(configuration[:control])
      when :adult_dashboard
        run_adult_dashboard(configuration[:control])
      when :equivalences
        run_equivalences(configuration[:control])
      when :kpi_analysis
        run_kpi_calculations(configuration)
      when :run_benchmark_charts_and_tables
        run_benchmark_charts_and_tables(configuration, @test_script[:schools])
      else
        configure_log_file(configuration) if component.to_s.include?('logger')
      end
    end
  end

  private

  def school_factory
    $SCHOOL_FACTORY ||= SchoolFactory.new
  end

  def load_school(school_name)
    school_factory.load_or_use_cached_meter_collection(:name, school_name, @meter_readings_source)
  end

  def update_dark_sky_temperatures
    DownloadDarkSkyTemperatures.new.download
  end

  def update_grid_carbon_intensity
    DownloadUKGridCarbonIntensity.new.download
  end

  def update_sheffield_solar_pv
    DownloadSheffieldSolarPVData.new.download
  end

  def determine_schools(config)
    logger.info '=' * 120
    @school_list = AnalysticsSchoolAndMeterMetaData.new.match_school_names(config)
    logger.info "Schools: #{@school_list}"
  end

  def banner(title)
    '=' * 60 + title.ljust(60, '=')
  end

  def run_reports(chart_list, control)
    logger.info '=' * 120
    logger.info 'RUNNING REPORTS'
    failed_charts = []
    @school_list.sort.each do |school_name|
      puts banner(school_name)
      @current_school_name = school_name
      reevaluate_log_filename
      school = load_school(school_name)
      charts = RunCharts.new(school)
      charts.run(chart_list, control)
      failed_charts += charts.failed_charts
    end
    RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
  end

  def run_drilldown
    @school_list.each do |school_name|
      excel_filename = File.join(File.dirname(__FILE__), '../Results/') + school_name + '- drilldown.xlsx'
      school = load_school(school_name)
      chart_manager = ChartManager.new(school)
      chart_name = :group_by_week_electricity
      chart_config = chart_manager.get_chart_config(chart_name)
      next unless chart_manager.drilldown_available?(chart_config)
      result = chart_manager.run_chart(chart_config, chart_name)
      fourth_column_in_chart = result[:x_axis_ranges][3]
      new_chart_name, new_chart_config = chart_manager.drilldown(chart_name, chart_config, nil, fourth_column_in_chart)
      new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)
      excel = ExcelCharts.new(excel_filename)
      excel.add_charts('Test', [result, new_chart_results])
      excel.close
    end
  end

  def run_timescales
    @school_list.each do |school_name|
      excel_filename = File.join(File.dirname(__FILE__), '../Results/') + school_name + '- timescale shift.xlsx'
      school = load_school(school_name)
      chart_manager = ChartManager.new(school)
      chart_name = :activities_14_days_daytype_electricity_cost 
      chart_config = chart_manager.get_chart_config(chart_name)
      result = chart_manager.run_chart(chart_config, chart_name)

      chart_list = [result]

      new_chart_config = chart_config

      %i[move extend contract compare].each do |operation_type|
        manipulator = ChartManagerTimescaleManipulation.factory(operation_type, new_chart_config, school)
        next unless manipulator.chart_suitable_for_timescale_manipulation?
        puts "Display button: #{operation_type} forward 1 #{manipulator.timescale_description}" if manipulator.can_go_forward_in_time_one_period?
        puts "Display button: #{operation_type} back 1 #{manipulator.timescale_description}"    if manipulator.can_go_back_in_time_one_period?
        next unless manipulator.enough_data?(-1) # shouldn't be necessary if conform to above button display
        new_chart_config = manipulator.adjust_timescale(-1) # go back one period
        new_chart_results = chart_manager.run_chart(new_chart_config, chart_name)
        chart_list.push(new_chart_results)
      end
      
      excel = ExcelCharts.new(excel_filename)
      excel.add_charts('Test', chart_list)
      excel.close
    end
  end

  def run_adult_dashboard(control)
    @school_list.sort.each do |school_name|
      school = load_school(school_name)
      puts "=" * 100
      puts "Running for #{school_name}"
      test = RunAdultDashboard.new(school)
      test.run_flat_dashboard(control)
    end
  end

  def run_equivalences(control)
    @school_list.sort.each do |school_name|
      school = load_school(school_name)
      puts "=" * 100
      puts "Running for #{school_name}"
      test = RunEquivalences.new(school)
      test.run_equivalences(control)
    end
  end

  def run_pupil_dashboard(control)
    run_dashboard(control)
  end

  private def run_dashboard(control)
    @school_list.each do |school_name|
      school = load_school(school_name)
      test = PupilDashboardTests.new(school)
      test.run_tests(control)
    end
  end

  

  def run_timescales_drilldown
    @school_list.each do |school_name|
      chart_list = []
      excel_filename = File.join(File.dirname(__FILE__), '../Results/') + school_name + '- drilldown and timeshift.xlsx'
      school = load_school(school_name)

      puts 'Calculating standard chart'

      chart_manager = ChartManager.new(school)
      chart_name = :pupil_dashboard_group_by_week_electricity_kwh
      chart_config = chart_manager.get_chart_config(chart_name)
      result = chart_manager.run_chart(chart_config, chart_name)
      puts "Year: group by week chart:"
      ap chart_config
      puts "Chart parent time description (nil?): #{chart_manager.parent_chart_timescale_description(chart_config)}"

      chart_list.push(result)

      puts 'drilling down onto first column of chart => week chart by day'

      [0, 2].each do |drilldown_chart_column_number|
        column_in_chart = result[:x_axis_ranges][drilldown_chart_column_number]
        new_chart_name, new_chart_config = chart_manager.drilldown(chart_name, chart_config, nil, column_in_chart)
        puts 'Week chart: 7 x days'
        ap new_chart_config
        puts "Chart parent time description(year?): #{chart_manager.parent_chart_timescale_description(new_chart_config)}"
        new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)
        chart_list.push(new_chart_results)

        puts 'Day chart: half hours'
        column_in_chart = result[:x_axis_ranges][drilldown_chart_column_number]
        new_chart_name, new_chart_config = chart_manager.drilldown(new_chart_name, new_chart_config, nil, column_in_chart)
        ap new_chart_config
        puts "Chart parent time description(week?): #{chart_manager.parent_chart_timescale_description(new_chart_config)}"
        new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)
        chart_list.push(new_chart_results)

        if true
          %i[move extend contract compare].each do |operation_type|
            puts "#{operation_type} chart 1 week"

            manipulator = ChartManagerTimescaleManipulation.factory(operation_type, new_chart_config, school)
            next unless manipulator.chart_suitable_for_timescale_manipulation?
            puts "Display button: #{operation_type} forward 1 #{manipulator.timescale_description}" if manipulator.can_go_forward_in_time_one_period?
            puts "Display button: #{operation_type} back 1 #{manipulator.timescale_description}"    if manipulator.can_go_back_in_time_one_period?
            next unless manipulator.enough_data?(1) # shouldn't be necessary if conform to above button display
            new_chart_config = manipulator.adjust_timescale(1) # go forward one period
            new_new_chart_results = chart_manager.run_chart(new_chart_config, chart_name)
            chart_list.push(new_new_chart_results)
          end
        end
      end

      puts 'saving result to Excel'

      excel = ExcelCharts.new(excel_filename)
      excel.add_charts('Test', chart_list)
      excel.close
    end
  end

  private def chart_drilldown(chart_manager:, chart_name:, chart_config:, previous_chart_results:, chart_results:, drilldown_chart_column_number: 0)
    column_in_chart = previous_chart_results[:x_axis_ranges][chart_results.last]
    new_chart_name, new_chart_config = chart_manager.drilldown(chart_name, chart_config, nil, column_in_chart)
    puts "Chart parent time description(year?): #{chart_manager.parent_chart_timescale_description(new_chart_config)}"
    new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)
    {
      chart_results:            new_chart_results,
      chart_name:               new_chart_name,
      parent_time_description:  chart_manager.parent_chart_timescale_description(new_chart_config)
  }
    chart_results.push(new_chart_results)
  end

  def run_kpi_calculations(config)
    calculation_results = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
    @school_list.sort.each do |school_name|
      school = load_school(school_name)
      calculation = KPICalculation.new(school)
      calculation.run_kpi_calculations
      calculation_results = calculation_results.deep_merge(calculation.calculation_results)
      KPICalculation.save_kpi_calculation_to_csv(config, calculation_results)
    end
  end

  def run_benchmark_charts_and_tables(control, schools)
    benchmark = RunBenchmarks.new(control, schools)
    benchmark.run
  end

  def run_alerts(alert_list, control)
    logger.info '=' * 120
    logger.info 'RUNNING ALERTS'
    failed_alerts = []
    ENV['ENERGYSPARKSTESTMODE'] = 'ON'
    dates = RunAlerts.convert_asof_dates(control[:asof_date])

    @school_list.each do |school_name|
      @current_school_name = school_name
      dates.each do |asof_date|
        reevaluate_log_filename
        school = load_school(school_name)
        start_profiler
        alerts = RunAlerts.new(school)
        alerts.run_alerts(alert_list, control, asof_date)
        stop_profiler
      end
      # failed_alerts += alerts.failed_charts
    end
    RunAlerts.print_calculation_time(control[:benchmark]) if control.key?(:benchmark)
    RunAlerts.save_priority_data(control[:save_priority_variables])
    RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
  end

  private def start_profiler
    RubyProf.start if @test_script.key?(:ruby_profiler)
  end

  private def stop_profiler
    if @test_script.key?(:ruby_profiler)
      prof_result = RubyProf.stop
      printer = RubyProf::GraphHtmlPrinter.new(prof_result)
      printer.print(File.open('log\code-profile - alerts' + Date.today.to_s + '.html','w'))
    end
  end

  def configure_log_file(configuration)
    @log_filename = configuration[:name]
    reevaluate_log_filename
  end

  def reevaluate_log_filename
    filename = @log_filename.is_a?(IO) ? @log_filename : (@log_filename % { school_name: @current_school_name, time: Time.now.strftime('%d %b %H %M') })
    @@es_logger_file.file = filename
  end
end
