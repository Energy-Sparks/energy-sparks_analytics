require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  standard: %i[baseload],
  boiler:   %i[boiler_start_time boiler_start_time_up_to_one_year]
}
overrides = {
  schools:  ['king-james-*'],
  charts:   { charts: charts, control: { } }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
