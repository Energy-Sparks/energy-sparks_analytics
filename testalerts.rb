# test new report manager

require './metersandschools'
require './alerts'

def banner(title)
  len_before = ((80 - title.length) / 2).floor
  len_after = 80 - title.length - len_before
  '=' * len_before + title + '*' * len_after
end
school_name = 'Bathwick St Marys'

ENV['ENERGYSPARKSDATASOURCE'] = 'csv'

school = School.new(school_name, 'Bath BA2', 1000.0, 100, :primary)

school.load_meters

analysis_asof_date = Date.new(2012, 11, 8)

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
