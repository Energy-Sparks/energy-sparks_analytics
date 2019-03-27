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
reports.load_school('Stanton Drew Primary School', true)

RubyProf.start if profile

#reports.do_all_standard_pages_for_school
reports.do_one_page(:storage_heaters)



if profile
  prof_result = RubyProf.stop
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('log\code-profile - test_dashboard' + Date.today.to_s + '.html','w')) # 'code-profile.html')
end

reports.save_excel_and_html

reports.report_benchmarks
