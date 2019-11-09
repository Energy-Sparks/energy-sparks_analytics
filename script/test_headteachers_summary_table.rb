# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-heads summary table ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

school_names = AnalysticsSchoolAndMeterMetaData.new.match_school_names('.*')

puts "Number of schools: #{school_names.length}"

school_names.each do |school_name|
  puts "<h2>#{school_name}</h2>"

  meter_collection = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)

  puts HeadTeachersSchoolSummaryTable.new(meter_collection).html
end


