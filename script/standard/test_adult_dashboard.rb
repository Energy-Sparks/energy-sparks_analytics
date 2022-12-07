require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  @logger = Logger.new(File.join('log', 'adult dashboard.log'))
  logger.level = :info
end

schools = ['king-james-ex*', 'wyb*'] # , 'wyb*'] # ['king-j*', 'combe-d*'] # ['ullapool-pv-storage_heaters_not_relevant*'] + SchoolFactory.storage_heater_schools

overrides = {
  schools: schools,
  cache_school: false,
  no_adult_dashboard: { control: { user: { user_role: :analytics, staff_role: nil } } },
  adult_dashboard: {
    control: { 
      no_pages: %i[benchmark],
      no_pages: %i[benchmark electric_annual gas_annual electric_out_of_hours gas_out_of_hours hotwater], # storage_heater
      compare_results: [ :summary, :report_differences],
      user: { user_role: :analytics, staff_role: nil }
    }
  },
  # adult_dashboard: { control: { pages: %i[boiler_control_thermostatic], user: { user_role: :analytics, staff_role: nil } } }
  # adult_dashboard: { control: { pages: %i[boiler_control_morning_start_time], user: { user_role: :analytics, staff_role: nil } } }
  # adult_dashboard: { control: { pages: %i[electric_target gas_target] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
