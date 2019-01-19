# test new report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-alerts ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :warn
end

def banner(title)
  len_before = ((80 - title.length) / 2).floor
  len_after = 80 - title.length - len_before
  '=' * len_before + title + '*' * len_after
end
school_name = 'Paulton Junior School'

ENV['School Dashboard Advice'] = 'Include Header and Body'
$SCHOOL_FACTORY = SchoolFactory.new

reports = ReportConfigSupport.new

school = reports.load_school(school_name, true)

analysis_asof_date = Date.new(2018, 3, 16)

puts
puts banner('Electricity Baseload Alert (v benchmark)')

alert_baseload = AlertElectricityBaseloadVersusBenchmark.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Electricity Baseload Alert (change)')

alert_baseload = AlertChangeInElectricityBaseloadShortTerm.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Electricity Daily Alert (change)')

alert_baseload = AlertChangeInDailyElectricityShortTerm.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Out of Hours Electricity Usage')

alert_baseload = AlertOutOfHoursElectricityUsage.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Annual Electricity Usage versus benchmark')

alert_baseload = AlertElectricityAnnualVersusBenchmark.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Annual Gas Usage versus benchmark')

alert_baseload = AlertGasAnnualVersusBenchmark.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Out of Hours Gas Usage')

alert_baseload = AlertOutOfHoursGasUsage.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Gas Daily Alert (change)')

alert_baseload = AlertChangeInDailyGasShortTerm.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Weekend gas consumption')

alert_baseload = AlertWeekendGasConsumptionShortTerm.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Upcoming holiday')

alert_baseload = AlertImpendingHoliday.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Heating On/Off based on forecast')

alert_baseload = AlertHeatingOnOff.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('Hot water system efficiency')

alert_baseload = AlertHotWaterEfficiency.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('heating coming on too early')

alert_baseload = AlertHeatingComingOnTooEarly.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results

puts
puts banner('thermostatic control')

alert_baseload = AlertThermostaticControl.new(school)
alert_baseload.analyse(analysis_asof_date)
results = alert_baseload.analysis_report
puts results
