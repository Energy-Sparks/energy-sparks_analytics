# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

# school_name = 'Westfield Primary'
module Logging
  # @logger = Logger.new('Results/test-simulator ' + Time.now.strftime('%H %M') + '.log')
  @logger = Logger.new(STDOUT)
  @logger.level = :info # :debug
end
ENV['AWESOMEPRINT'] = 'off'
ENV['School Dashboard Advice'] = 'Include Header and Body'

puts "========================================================================================"
puts  "Heating Model Fitting"

suppress_school_loading_output = true

school_name_pattern_match = ['trini*']
source_db = :unvalidated_meter_data

list_of_schools = RunTests.resolve_school_list(source_db, school_name_pattern_match)

reports = ReportConfigSupport.new

list_of_schools.each do |school_name|

  puts "Processing #{school_name}"

  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  next if school.aggregated_heat_meters.nil?

  fitter = HeatingRegressionModelFitter.new(school)

  document = fitter.fit

  all_html = ''
  all_charts = []
  document.each do |doc|
    if doc.type == :html
      all_html += doc.content
    elsif doc.type == :chart
      all_charts.push(doc.content)
    end
  end

  html_writer = HtmlFileWriter.new('heating fitting ' +   school_name)
  html_writer.write(all_html)
  html_writer.close

  reports.worksheet_charts['Original'] = all_charts
  reports.excel_name = school_name + ' - heating regression model fitting'
  reports.write_excel

  exit # do only one school for the moment
end

