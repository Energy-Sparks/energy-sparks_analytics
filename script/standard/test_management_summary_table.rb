# test report manager
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
require './script/report_config_support.rb'

overrides = {
  schools:  ['a*']
}

script = RunManagementSummaryTable.default_config.deep_merge(overrides)

RunTests.new(script).run

