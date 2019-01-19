# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-dashboard ideas ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

reports = ReportConfigSupport.new

school_name = 'Trinity First School' # 'Trinity First School'

school = reports.load_school(school_name, true)

asof_date = Date.new(2018,2,2)
AlertAnalysisBase.valid_alerts(school, asof_date)

reports.do_chart_list('Meter breakdown', [
  :sprint2_last_2_weeks_electricity_by_datetime,
  :sprint2_last_2_weeks_electricity_by_datetime_column,
  :sprint2_last_2_weeks_electricity_by_day_line,
  :sprint2_last_2_weeks_electricity_by_day_column,
  :sprint2_last_2_weeks_gas_by_datetime,
  :sprint2_last_2_weeks_gas_by_datetime_column,
  :sprint2_last_2_weeks_gas_by_day_line,
  :sprint2_last_2_weeks_gas_by_day_column,
  :sprint2_gas_comparison,
  :benchmark
])

reports.excel_name = 'Dashboard ideas for ' + school_name

reports.save_excel_and_html
