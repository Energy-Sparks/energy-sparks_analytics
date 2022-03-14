require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  # standard: %i[group_by_week_electricity_meter_breakdown_one_year],
  boiler:   %i[boiler_start_time boiler_start_time_up_to_one_year boiler_start_time_up_to_one_year_no_frost]
}

no_charts = RunCharts.standard_charts_for_school

control = {
  save_to_excel:  true,

  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts,
  ]
}

overrides = {
  schools:  ['king-ja*'], # ['king-ja*', 'marksb*', 'long*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
