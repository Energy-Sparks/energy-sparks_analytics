require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

overrides = { 
  schools: [ '*' ],
  # adult_dashboard: { control: { pages: %i[ storage_heater] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
