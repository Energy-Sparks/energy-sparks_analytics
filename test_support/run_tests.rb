require_relative './logger_control.rb'
require_relative './test_directory_configuration.rb'
$logger_format = 1

class RunTests
  include Logging
  include TestDirectoryConfiguration

  DEFAULT_TEST_SCRIPT = {
    logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
=begin
    dark_sky_temperatures:    nil,
    grid_carbon_intensity:    nil,
    sheffield_solar_pv:       nil,
=end
    schools:                  ['.*'],
    source:                   :analytics_db,
    logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
=begin
    reports:                  {
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
=end   
                              alerts:                   {
                                  alerts:   [ AlertHeatingComingOnTooEarly ],
                                  control:  {
                                              # print_alert_banner: true,
                                              # alerts_history: true,
                                              print_school_name_banner: true,
                                              # outputs:           [ :front_end_template_variables ],
                                              save_and_compare:  {
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
                                              asof_date:          Date.new(2019, 6, 30)
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
    @school_list.each do |school_name|
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

  def run_alerts(alert_list, control)
    logger.info '=' * 120
    logger.info 'RUNNING ALERTS'
    failed_alerts = []
    @school_list.each do |school_name|
      @current_school_name = school_name
      reevaluate_log_filename
      school = load_school(school_name)
      alerts = RunAlerts.new(school)
      alerts.run_alerts(alert_list, control)
      # failed_alerts += alerts.failed_charts
    end
    # RunCharts.report_failed_charts(failed_charts, control[:report_failed_charts]) if control.key?(:report_failed_charts)
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
