# test report manager
require 'ruby-prof'
require 'benchmark/memory'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

script = {
  
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/targetting %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  schools:                  ['bathamp*','trini*'],
  source:                   :unvalidated_meter_data,
  logger2:                  { name: "./log/targetting %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  reports:                  {
                              charts: [
                                adhoc_worksheet: { 
                                  name: 'Test', 
                                  charts: %i[
                                    targeting_and_tracking_monthly_electricity_experimental_baseload
                                  ]
                                },
                              ],
                              old: {
                                charts: %i[
                                  targeting_and_tracking_weekly_electricity_1_year
                                  targeting_and_tracking_monthly_electricity_internal_calculation
                                  targeting_and_tracking_monthly_electricity
                                  targeting_and_tracking_monthly_electricity_experimental
                                  targeting_and_tracking_monthly_electricity_experimental0
                                  targeting_and_tracking_monthly_electricity_experimental1
                                  targeting_and_tracking_monthly_electricity_experimental2
                                  targeting_and_tracking_monthly_electricity_experimental3
                                  targeting_and_tracking_monthly_electricity_experimental4
                                  targeting_and_tracking_monthly_electricity_experimental_baseload
                                ]
                              },
                              control: {
                              }
                            }, 
}

RunTests.new(script).run
