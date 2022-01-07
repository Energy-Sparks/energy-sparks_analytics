require_relative './logger_control.rb'
require_relative './test_directory_configuration.rb'
require 'ruby-prof'
$logger_format = 1

class RunTests
  include Logging
  include TestDirectoryConfiguration

  DEFAULT_TEST_SCRIPT = {
    logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
    ruby_profiler:            true,
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
        @school_name_pattern_match = configuration
      when :source
        @meter_readings_source = configuration
      when :meter_attribute_overrides
        @meter_attribute_overrides = configuration
      when :reports
        $logger_format = 2
        run_reports(configuration[:charts], configuration[:control])
      when :alerts
        run_alerts(configuration[:alerts], configuration[:control])
      when :drilldown
        run_drilldown
      when :generate_analytics_school_meta_data
        generate_analytics_school_meta_data
      when :timescales
        run_timescales
      when :timescale_and_drilldown
        run_timescales_drilldown
      when :pupil_dashboard
        run_pupil_dashboard(configuration[:control])
      when :adult_dashboard
        run_adult_dashboard(configuration[:control])
      when :targeting_and_tracking
        run_targeting_and_tracking(configuration[:control])
      when :equivalences
        run_equivalences(configuration[:control])
      when :kpi_analysis
        run_kpi_calculations(configuration)
      when :model_fitting
        run_model_fitting(configuration[:control])
      when :run_benchmark_charts_and_tables
        run_benchmark_charts_and_tables(configuration, @test_script[:schools], @test_script[:source])
      when :management_summary_table
        run_management_summary_tables(configuration[:combined_html_output_file], configuration[:control])
      else
        configure_log_file(configuration) if component.to_s.include?('logger')
      end
    end

    RecordTestTimes.instance.save_csv
  end

  private

  def school_factory
    $SCHOOL_FACTORY ||= SchoolFactory.new
  end

  def load_school(school_name, cache_school = false)
    school = nil
    begin
      attributes_override = @meter_attribute_overrides.nil? ? {} : @meter_attribute_overrides
      school = school_factory.load_or_use_cached_meter_collection(:name, school_name, @meter_readings_source, meter_attributes_overrides: attributes_override, cache: cache_school == true)
    rescue Exception => e
      puts "=" * 100
      puts "Load of school #{school_name} failed"
      puts "=" * 100
      puts e.message
      puts e.backtrace
    end
    school
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

  def banner(title)
    '=' * 60 + title.ljust(60, '=')
  end

  def run_reports(chart_list, control)
    logger.info '=' * 120
    logger.info 'RUNNING REPORTS'
    failed_charts = []
    start_profiler
    schools_list.sort.each do |school_name|
      puts banner(school_name)
      @current_school_name = school_name
      reevaluate_log_filename
      school = load_school(school_name, control[:cache_school])
      next if school.nil?
      charts = RunCharts.new(school)
      charts.run(chart_list, control)
      failed_charts += charts.failed_charts
    end
    stop_profiler('reports')
    RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
  end

  def run_drilldown
    schools_list.each do |school_name|
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
    schools_list.each do |school_name|
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
    run_specialised_dashboard(control, RunAdultDashboard)
  end

  def run_targeting_and_tracking(control)
    run_specialised_dashboard(control, RunTargetingAndTracking)
    filename = "#{control[:stats_csv_file_base]} #{Time.now.strftime('%d-%m-%Y %H-%M')}.csv"
    RunTargetingAndTracking.save_stats_to_csv(filename)
  end

  def run_specialised_dashboard(control, run_class)
    differences = {}
    failed_charts = []
    schools_list.sort.each do |school_name|
      school = load_school(school_name)
      puts "=" * 100
      puts "Running for #{school_name}"
      start_profiler
      test = run_class.new(school)
      differences[school_name] = test.run_flat_dashboard(control)
      stop_profiler('adult dashboard')
      failed_charts += test.failed_charts
    end
    run_class.summarise_differences(differences, control) if !control[:summarise_differences].nil? && control[:summarise_differences]
    RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
  end

  def run_management_summary_tables(combined_html_output_file, control)
    html = ""
    schools_list.sort.each do |school_name|
      school = load_school(school_name)
      puts "=" * 30
      puts "running for summary management table for #{school_name}"
      start_profiler
      test = RunManagementSummaryTable.new(school)
      test.run_management_table(control)
      stop_profiler('management table')
      html += "<h2>#{school.name}</h2>" + test.html
    end
    html_writer = HtmlFileWriter.new(control[:combined_html_output_file])
    html_writer.write(html)
    html_writer.close
  end

  def run_equivalences(control)
    schools_list.sort.each do |school_name|
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
    schools_list.each do |school_name|
      school = load_school(school_name)
      test = PupilDashboardTests.new(school)
      test.run_tests(control)
    end
  end

  def run_timescales_drilldown
    schools_list.each do |school_name|
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
    schools_list.sort.each do |school_name|
      school = load_school(school_name)
      calculation = KPICalculation.new(school)
      calculation.run_kpi_calculations
      calculation_results = calculation_results.deep_merge(calculation.calculation_results)
      KPICalculation.save_kpi_calculation_to_csv(config, calculation_results)
    end
  end

  def run_benchmark_charts_and_tables(control, schools, source)
    benchmark = RunBenchmarks.new(control, schools, source)
    benchmark.run
  end

  def run_model_fitting(control)
    logger.info '=' * 120
    logger.info 'RUNNING MODEL FITTING'
    failed_charts = []
    schools_list.sort.each do |school_name|
      puts banner(school_name)
      @current_school_name = school_name
      reevaluate_log_filename
      school = load_school(school_name)
      charts = RunModelFitting.new(school)
      charts.run(control)
      failed_charts += charts.failed_charts
    end
  end

  def run_alerts(alert_list, control)
    logger.info '=' * 120
    logger.info 'RUNNING ALERTS'
    failed_alerts = []
    ENV['ENERGYSPARKSTESTMODE'] = 'ON'
    dates = RunAlerts.convert_asof_dates(control[:asof_date])

    schools_list.each do |school_name|
      @current_school_name = school_name
      dates.each do |asof_date|
        reevaluate_log_filename
        school = load_school(school_name)
        start_profiler
        alerts = RunAlerts.new(school)
        alerts.run_alerts(alert_list, control, asof_date)
        stop_profiler('alerts')
      end
      # failed_alerts += alerts.failed_charts
    end
    RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
  end

  private def start_profiler
    RubyProf.start if @test_script[:ruby_profiler] == true
  end

  private def stop_profiler(name)
    if @test_script[:ruby_profiler] == true
      prof_result = RubyProf.stop
      printer = RubyProf::GraphHtmlPrinter.new(prof_result)
      printer.print(File.open('log\code-profile - ' + name + Date.today.to_s + '.html','w'))
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

  def schools_list
    RunTests.resolve_school_list(@meter_readings_source, @school_name_pattern_match)
  end

  def self.resolve_school_list(source, school_name_pattern_match)
    list = case source
    when :analytics_db
      AnalysticsSchoolAndMeterMetaData.new.match_school_names(school_name_pattern_match)
    when :aggregated_meter_collection
      matching_yaml_files_in_directory('aggregated-meter-collection-', school_name_pattern_match)
    when :validated_meter_collection
      matching_yaml_files_in_directory('validated-data-', school_name_pattern_match)
    when :unvalidated_meter_collection
      matching_yaml_files_in_directory('unvalidated-meter-collection', school_name_pattern_match)
    when :unvalidated_meter_data, :dcc_n3rgy_override_with_files
      matching_yaml_files_in_directory('unvalidated-data-', school_name_pattern_match)
    end
    puts "Running tests for #{list.length} schools: #{list.join('; ')}"
    list
  end

  def self.matching_yaml_files_in_directory(file_type, school_pattern_matches)
    filenames = school_pattern_matches.map do |school_pattern_match|
      match = file_type + school_pattern_match + '.yaml'
      Dir[match, base: SchoolFactory::METER_COLLECTION_DIRECTORY]
    end.flatten.uniq
    filenames.map { |filename| filename.gsub(file_type,'').gsub('.yaml','') }
  end

  def generate_analytics_school_meta_data
    meta_data = {}
    schools_list.sort.each do |school_name|
      school = load_school(school_name)
      puts "Loaded School #{school.name}"
      meta_data[school.name] = {}
      meta_data[school.name][:name]         = school.name
      meta_data[school.name][:postcode]     = school.postcode
      meta_data[school.name][:urn]         = school.urn
      meta_data[school.name][:area]         = school.area_name
      meta_data[school.name][:floor_area]   = school.floor_area
      meta_data[school.name][:pupils]       = school.number_of_pupils
      meta_data[school.name][:school_type]  = school.school_type
      meta_data[school.name][:meters]  = []
      unless school.electricity_meters.empty?
        school.electricity_meters.each do |meter|
          meta_data[school.name][:meters].push(
            {
              mpan:         meter.mpan_mprn,
              meter_type:   meter.fuel_type,
              name:         meter.name.empty? ? 'Unknown' : meter.name
            }
          )
        end
      end
      unless school.heat_meters.empty?
        school.heat_meters.each do |meter|
          meta_data[school.name][:meters].push(
            {
              mprn:         meter.mpan_mprn,
              meter_type:   meter.fuel_type,
              name:         meter.name.empty? ? 'Unknown' : meter.name
            }
          )
        end
      end
    end
    filename = './MeterReadings/autogeneratedschoolsandmeters.yml'
    puts "Saving #{filename}"
    File.open(filename, 'w') { |f| f.write(YAML.dump(meta_data)) }
    # puts YAML.dump(meta_data)
  end
end
