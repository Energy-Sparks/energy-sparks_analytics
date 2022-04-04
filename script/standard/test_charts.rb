require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

charts = {
  bm:   %i[targeting_and_tracking_weekly_electricity_one_year_line]
}

charts = RunCharts.standard_charts_for_school

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
  schools:  ['*'], # ['chase-lane-target*'], # ['king-ja*', 'marksb*', 'long*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

begin
  RunTests.new(script).run
rescue => e
  puts e.message
  puts e.backtrace
end
