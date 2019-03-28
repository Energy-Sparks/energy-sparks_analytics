# test report manager
require 'ruby-prof'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

@@energysparksanalyticsautotest = {
  original_data: '../TestResults/Charts/Base/',
  new_data:      '../TestResults/Charts/New/'
}

module Logging
  @logger = Logger.new('log/test-regression_model ' + Time.now.strftime('%H %M') + '.log')
  # @logger = Logger.new(STDOUT)
  logger.level = :error
end

profile = false
prof_result = nil

reports = ReportConfigSupport.new

list_of_schools = reports.schools.keys

module Logging
  logger.level = :debug
end
csv_results = []

list_of_schools.reverse.each do |school_name|
  # next if school_name != 'St Marks Secondary'

  # next if ['Saltford C of E Primary School', 'Hunters Bar School', 'Roundhill School'].include?(school_name)
  # next if !['St Saviours Junior'].include?(school_name)

  if reports.schools[school_name] == :electric_only
    puts '=' * 100, "Unable to analyse #{school_name} as no gas", "\n" * 4
    next
  end

  puts '=' * 100, "#{school_name}"

  school = reports.load_school(school_name, true)

  puts school.all_heat_meters.length

  RubyProf.start if profile

  school.all_heat_meters.each do |meter|
    meter_name = meter.mpan_mprn.to_s
    # next if meter_name != '75665806'
    meter_name += meter.name[0..10] unless meter.name.nil?

    @@energysparksanalyticsautotest[:name_extension] = meter.mpan_mprn
    reports.do_one_page(:heating_model_fitting, false, {meter_definition: meter.mpan_mprn}, meter.mpan_mprn)
    unless meter.model_cache.results(:best).nil?
      model_result_keys, model_results = meter.model_cache.results(:best).model_configuration_csv_format
      csv_results.push([model_result_keys, model_results])
    end
  end

  prof_result = RubyProf.stop if profile

  reports.excel_name = school_name + ' - regression test'

  reports.save_excel_and_html
end

if profile
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('code-profile - test_regression_model.html','w')) # 'code-profile.html')
end

reports.report_benchmarks

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
