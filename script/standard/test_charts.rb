require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  standard: %i[baseload],
  boiler:   %i[boiler_start_time boiler_start_time_up_to_one_year]
}.merge(RunCharts.standard_charts_for_school)

RunCharts.standard_charts_for_school

control = {
  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts,
  ]
}

overrides = {
  schools:  ['*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
