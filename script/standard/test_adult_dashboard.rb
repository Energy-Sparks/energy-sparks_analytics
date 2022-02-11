require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

overrides = { 
  schools: ['bath*'],
  # adult_dashboard: { control: { pages: pages: %i[baseload] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
