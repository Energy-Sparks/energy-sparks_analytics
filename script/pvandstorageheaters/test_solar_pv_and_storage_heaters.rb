# test report manager
require 'ruby-prof'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
  # @logger = Logger.new(STDOUT)
  logger.level = :debug
end

profile = false

reports = ReportConfigSupport.new

# reports.load_school('Coit Primary School', true)
reports.load_school('Stanton Drew Primary School', true)
# reports.load_school('Paulton Junior School', true)
# testing examples
#
#   reports.do_all_schools(true)
#   reports.do_all_standard_pages_for_school
#   reports.do_one_page(:main_dashboard_electric_and_gas)
#   reports.do_chart_list('Boiler Control', [:hotwater, :frost_2, :optimum_start])
#

RubyProf.start if profile

# reports.do_chart_list('Boiler Control', [:gas_heating_season_intraday, :gas_heating_season_intraday_£])

reports.do_one_page(:solar_pv)

if profile
  prof_result = RubyProf.stop
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('log\code-profile - test_dashboard' + Date.today.to_s + '.html','w')) # 'code-profile.html')
end

reports.save_excel_and_html

reports.report_benchmarks
