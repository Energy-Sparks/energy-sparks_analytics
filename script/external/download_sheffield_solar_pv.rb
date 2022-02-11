  # 
# test report manager
require 'ruby-prof'
require 'benchmark/memory'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

script = {
  logger1:                  { name: TestDirectory.instance.log_directory + "/sheffieldpv %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  sheffield_solar_pv:       nil,
}

RunTests.new(script).run
