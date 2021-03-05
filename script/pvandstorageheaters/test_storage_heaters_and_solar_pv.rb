# test storage heater and solar pv code
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

module Logging
  @logger = Logger.new('log/test-storage-heaters-and-solar-pv.log')
  logger.level = :warn
end

Logging.logger.debug "\n" * 10
pp "Running Test Storage Heaters and Solar PV"

school_name = 'Stanton Drew Primary School' # ''

ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
#ENV['CACHED_METER_READINGS_DIRECTORY'] = File.join(File.dirname(__FILE__), '/MeterReadings/')

$SCHOOL_FACTORY = SchoolFactory.new

school = $SCHOOL_FACTORY.load_school(school_name)

Logging.logger.debug "SCHOOL IS A #{school.class.name}"
Logging.logger.debug "Floor area is #{school.floor_area}"
# logger.debug school.meter_collection.methods
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
