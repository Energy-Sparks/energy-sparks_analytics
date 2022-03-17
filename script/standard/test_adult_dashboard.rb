require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  logger.level = :debug
end

storage_heater_schools = ['penny*', 'tomna*', 'plump*', 'cats*', 'combe', 'inver*','marks*', 'miller*','stanton*', 'st-jul*','tomna*']

overrides = { 
  schools: storage_heater_schools
  # adult_dashboard: { control: { pages: %i[electric_annual] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

RunTests.new(script).run
