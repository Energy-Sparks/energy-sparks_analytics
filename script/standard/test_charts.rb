require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  standard: %i[electricity_kwh_last_7_days_with_co2_intensity],
  # boiler:   %i[boiler_start_time boiler_start_time_up_to_one_year]
}

charts = RunCharts.standard_charts_for_school

control = {
  save_to_excel:  true,

  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts,
  ]
}

overrides = {
  schools:  ['king-ja*', 'marksb*', 'long*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
