# test storage heater and solar pv code
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

puts "\n" * 10
pp "Running Test Storage Heaters and Solar PV"

school_name = 'Stanton Drew Primary School' # ''

ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
#ENV['CACHED_METER_READINGS_DIRECTORY'] = File.join(File.dirname(__FILE__), '/MeterReadings/')

$SCHOOL_FACTORY = SchoolFactory.new

school = $SCHOOL_FACTORY.load_school(school_name)

puts "SCHOOL IS A #{school.class.name}"
puts "Floor area is #{school.floor_area}"
# puts school.meter_collection.methods
# exit
reportmanager = ReportManager.new(school)

reports = {
  'Main Dashboard' => %i[intraday_line] # thermostatic cusum baseload intraday_line]
}

worksheets = reportmanager.run_reports(reports)

excel = ExcelCharts.new(File.join(File.dirname(__FILE__), '../Results/') + school_name + '- charts test.xlsx')

worksheets.each do |worksheet_name, charts|
  excel.add_charts(worksheet_name, charts)
end

excel.close
