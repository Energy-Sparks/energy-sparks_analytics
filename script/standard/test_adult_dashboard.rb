require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

overrides = { 
  schools: ['our-lady*'],
  # adult_dashboard: { control: { pages: %i[boiler_control_thermostatic] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
