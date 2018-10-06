# test chart drilldown
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
#  @logger = Logger.new('log/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
#  logger.level = :debug
end


reports = ReportConfigSupport.new

school_name = 'St Marks Secondary'
ReportConfigSupport.suppress_output(school_name) {
  reports.load_school(school_name, true)
}

reports.do_chart_list('Test Drilldown', [:benchmark, :benchmark_drildown, :benchmark_drildown_drilldown])

reports.save_excel_and_html

reports.report_benchmarks
