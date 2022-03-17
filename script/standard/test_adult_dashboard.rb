require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

overrides = {
  schools: ['balli*'],
  # adult_dashboard: { control: { pages: %i[boiler_control_morning_start_time], user: { user_role: :analytics, staff_role: nil } } }
  adult_dashboard: { control: { pages: %i[ gas_target] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
