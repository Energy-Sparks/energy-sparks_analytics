# test report manager
require './chartmanager'
require './excelcharts'
require './reportmanager'
require './schoolfactory'

puts "\n" * 10

# making some more changes here
school_name = 'St Johns Primary'

ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
ENV['CACHED_METER_READINGS_DIRECTORY'] = './MeterReadings/'

$SCHOOL_FACTORY = SchoolFactory.new

school = $SCHOOL_FACTORY.load_school(school_name)

# school.load_meters

=begin
chart_manager = ChartManager.new(school)

charts = chart_manager.run_standard_charts
=end

reportmanager = ReportManager.new(school)
worksheets = reportmanager.run_reports(reportmanager.standard_reports)

excel = ExcelCharts.new('.\\Results\\' + school_name + '- charts test.xlsx')

worksheets.each do |worksheet_name, charts|
  excel.add_charts(worksheet_name, charts)
end
=begin
charts.each do |chart|
  # puts chart.inspect
  excel.add_graph_and_data("Blob", chart)
end
=end
excel.close

# puts "Got #{charts.length} charts"
