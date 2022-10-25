require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new(File.join('log', 'test charts.log'))
  logger.level = :debug
end

charts = {
  # bm:   %i[community_use_test_electricity management_dashboard_group_by_week_electricity]
  solar: %i[management_dashboard_group_by_week_electricity]
}

no_charts = { adhoc: %i[group_by_week_gas_versus_benchmark intraday_line_school_days_gas_reduced_data_versus_benchmarks] }

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
  schools:  ['balfour*'], # ['hugh*', 'herst*'], # ['tow*', 'st-julian-s-h*'], # ['chase-lane-target*'], # ['king-ja*', 'marksb*', 'long*'],
  cache_school: false,
  charts:   { charts: charts, control: control }
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

begin
  RunTests.new(script).run
rescue => e
  puts e.message
  puts e.backtrace
end
