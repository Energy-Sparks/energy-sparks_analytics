require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  # standard: %i[group_by_week_electricity_meter_breakdown_one_year],
  boiler:   %i[targeting_and_tracking_weekly_electricity_to_date_line]
}

no_charts = RunCharts.standard_charts_for_school

# charts = RunCharts.targeting_and_tracking_charts

control = {
  save_to_excel:  true,

  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts
  ]
}

overrides = {
  schools:  ['chase-silly*'], # ['chase-lane-target*'], # ['king-ja*', 'marksb*', 'long*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

RunTests.new(script).run
