# test report manager
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
require './script/report_config_support.rb'

overrides = {
  schools:  ['ullapool-pv-storage_heaters_not_relevant*']
}

script = RunManagementSummaryTable.default_config.deep_merge(overrides)

RunTests.new(script).run

