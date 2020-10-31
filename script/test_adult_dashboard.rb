require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['pault*'], # ['.*','Farr.*', 'King Ed.*', 'Round.*'],
  no_source:                 :analytics_db,
  source:                   :aggregated_meter_collection,
  logger2:                  { name: "./log/pupil dashboard %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  adult_dashboard:          {
                              control: {
                                root:    :adult_analysis_page, # :pupil_analysis_page,
                                no_chart_manipulation: %i[drilldown timeshift],
                                display_average_calculation_rate: true,
                                report_failed_charts:   :summary, # :detailed
                                user:          { user_role: :analytics, staff_role: nil }, # nil, # , # { user_role: :admin }, # guest
                                no_pages: %i[electricity_profit_loss gas_profit_loss],
                                compare_results: [
                                  { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\AdultDashboard\Base' },
                                  { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\AdultDashboard\New' },
                                  :summary,
                                  # :report_differences
                                  # :report_differing_charts,
                                  # :report_differences 
                                ] # :quick_comparison,
                              }
                            }
}

RunTests.new(script).run