require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log\chart logs.log')
  logger.level = :error
end

charts = {
  bm:   %i[group_by_week_electricity_unlimited]
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
  charts:   { charts: charts, control: control },
  control: { cache_school: false },
}

script = RunAnalyticsTest.default_config.deep_merge(overrides)

begin
  RunTests.new(script).run
rescue => e
  puts e.message
  puts e.backtrace
end
