require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

schools = ['ullapool-pv*'] # ['ullapool-pv-storage_heaters_not_relevant*'] + SchoolFactory.storage_heater_schools

overrides = {
  schools: schools,
  # adult_dashboard: { control: { pages: %i[boiler_control_morning_start_time], user: { user_role: :analytics, staff_role: nil } } }
  adult_dashboard: { control: { pages: %i[electric_target gas_target] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
