# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('Results/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

reports = ReportConfigSupport.new

reports.load_school('Castle Primary School', true)

# testing examples
#
#   reports.do_all_schools(true)
#   reports.do_all_standard_pages_for_school
#   reports.do_one_page(:main_dashboard_electric_and_gas)
#   reports.do_chart_list('Boiler Control', [:hotwater, :frost_2, :optimum_start])
#
# comment excel/html out if calling reports.do_all_schools or reports.do_all_standard_pages_for_school
# as done automatically:

reports.do_all_standard_pages_for_school
# reports.do_one_page(:main_dashboard_electric_and_gas)
# reports.do_one_page(:test)

reports.save_excel_and_html

reports.report_benchmarks
