require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['bath*'],
  source:                   :unvalidated_meter_data,
  logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  alerts:                   {
    no_alerts:   [ AlertPreviousYearHolidayComparisonElectricity ],
    alerts: nil,
    control:  {
                compare_results: {
                  summary:              :differences, # true || false || :detail || :differences
                  report_if_differs:    true,
                  methods:              %i[raw_variables_for_saving],   # %i[ raw_variables_for_saving front_end_template_data front_end_template_chart_data front_end_template_table_data
                  class_methods:        %i[front_end_template_variables],
                  comparison_directory: ENV['ANALYTICSTESTRESULTDIR'] + '\Alerts\Base',
                  output_directory:     ENV['ANALYTICSTESTRESULTDIR'] + '\Alerts\New'
                },

                charts: {
                  calculate:      false,
                  write_to_excel: false
                },

                log: %i[:failed_calculations], # :sucessful_calculations, :invalid_alerts

                no_outputs:     %i[front_end_template_variables front_end_template_data front_end_template_tables front_end_template_table_data], # front_end_template_variables front_end_template_data raw_variables_for_saving],
                asof_date:      Date.new(2021, 12, 10)
              }
  }
}

RunTests.new(script).run
