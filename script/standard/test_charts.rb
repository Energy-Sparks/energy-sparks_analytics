require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new(File.join('log', 'logs.log'))
  logger.level = :error
end

charts = {
  bm:   %i[management_dashboard_group_by_month_solar_pv_unlimited solar_pv_last_7_days_by_submeter]
}

no_charts = RunCharts.standard_charts_for_school

control = {
  save_to_excel:  true,

  compare_results: [
    :summary,
    :report_differences,
    :report_differing_charts
  ]
}

overrides = {
  schools:  ['*'], # ['tow*', 'st-julian-s-h*'], # ['chase-lane-target*'], # ['king-ja*', 'marksb*', 'long*'],
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

begin
  RunTests.new(script).run
rescue => e
  puts e.message
  puts e.backtrace
end
