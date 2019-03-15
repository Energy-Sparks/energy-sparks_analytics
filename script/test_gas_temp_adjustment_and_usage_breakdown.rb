# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-gas adjustment ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

reports = ReportConfigSupport.new

reports.load_school('Whiteways Primary', true)
reports.do_chart_list('Meter breakdown', [:sprint2_last_2_weeks_gas_by_day_column, :last_2_week_gas_comparison_with_adjusted_temperature])

reports.save_excel_and_html

reports.report_benchmarks
