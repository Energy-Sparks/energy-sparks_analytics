require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

no_charts = {
  standard: %i[baseload],
  boiler:   %i[boiler_start_time boiler_start_time_up_to_one_year]
}

charts = RunCharts.standard_charts_for_school

RunCharts.standard_charts_for_school

control = {
  save_to_excel:  false,

  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts,
  ]
}

overrides = {
  schools:  ['king-ja*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
