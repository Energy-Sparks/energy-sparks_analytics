# test report manager
require 'ruby-prof'
require 'benchmark/memory'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # logger1:                  { name: STDOUT, format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  # dark_sky_temperatures:    nil,
  # grid_carbon_intensity:    nil,
  # sheffield_solar_pv:       nil,
  no_schools:                  ['hhhhhhhhh*'], # ['Round.*'],
  no_source:                   :aggregated_meter_collection,
  # generate_analytics_school_meta_data: true,
  schools:                  ['st-phili*'],
  no_source:                   :analytics_db, # :aggregated_meter_collection :load_unvalidated_meter_collection, 
  source: :unvalidated_meter_data,
  # 
  logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  reports:                  {
                              charts: [
                                :dashboard,
                                no_adhoc_worksheet: { name: 'Test', charts: %i[
                                  acc1
                                  acc2
                                  acc3
                                  acc4
                                  ]},
                                # adhoc_worksheet: { name: 'Test', charts: %i[calendar_picker_electricity_week_example_comparison_chart
                                #   calendar_picker_electricity_day_example_comparison_chart] }
                                # :dashboard
                                # adhoc_worksheet: { name: 'Test', charts: %i[teachers_landing_page_storage_heaters teachers_landing_page_storage_heaters_simple] }
                                # pupils_dashboard: :pupil_analysis_page
                              ],
                              control: {
                                display_average_calculation_rate: true,
                                report_failed_charts:   :summary, 
                                # :detailed
                                compare_results:        [ 
                                  :summary, 
                                  :quick_comparison,
                                #  :report_differing_charts, 
                                # :report_differences
                              ] # :quick_comparison,
                              }
                            }, 
}

RunTests.new(script).run
