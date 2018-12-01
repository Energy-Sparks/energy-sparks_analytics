# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-schoolaveraging ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

reports = ReportConfigSupport.new

reports.load_school('St Marks Secondary', true) # dummy load to keep  report config happy

aggregation_definition = {
  name:       'Average School',
  urn:        123456789,
  floor_area: 1000.0,
  pupils:     200,
  schools: [
              { urn: 109089 },  # Paulton Junior
              { urn: 109328 },  # St Marks
              { urn: 109005 },  # St Johns
              { urn: 109081 }   # Castle
  ]  
}

school_averager = AverageSchoolAggregator.new(aggregation_definition)
school_averager.calculate()

exit
combined_charts_test_list = %i[
  group_by_week_electricity_school_comparison
  electricity_longterm_trend_school_comparison
  intraday_line_school_days_school_comparison
]

reports.do_chart_list('Combined', combined_charts_test_list)

reports.excel_name = 'Averaging School Test'

reports.save_excel_and_html

reports.report_benchmarks
