# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-electricity_statistics ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

reports = ReportConfigSupport.new

list_of_schools = reports.schools.keys

csv_results = []

list_of_schools.reverse.each do |school_name|
  # next if school_name != 'Freshford C of E Primary'
  if reports.schools[school_name] == :electric_only
    puts '=' * 100
    puts "Unable to analyse #{school_name} as no gas"
    next
  end
  
  puts '=' * 100
  puts "#{school_name}"
  reports.load_school(school_name, true)

  analysis = BenchmarkAnalyser::AnalyseDropInSummerHolidayBaseload.new(reports.school)
  analysis.analyse

  reports.do_chart_list('Electricity Analysis', [:baseload])

  # model_result_keys, model_results = reports.school.model_cache.results(:best).model_configuration_csv_format

  # csv_results.push([model_result_keys, model_results])

  reports.excel_name = school_name + ' - electricity stats'

  reports.save_excel_and_html
end
reports.report_benchmarks

=begin
csv_header = []
csv_data = []
csv_results.each do |header_and_data|
  header = header_and_data[0]
  csv_header = (csv_header + header).uniq
end
csv_data = []
csv_results.each do |header_and_data|
  row = []
  header = header_and_data[0]
  data = header_and_data[1]
  csv_header.each do |column_name|
    indx = header.find_index(column_name)
    row.push(indx.nil? ? nil : data[indx])
  end
  csv_data.push(row)
end

filename = 'log/model results.csv'

File.open(filename, 'w') do |file|
  file.puts csv_header.join(',')
  csv_data.each do |row|
    file.puts row.join(',')
  end
end
=end