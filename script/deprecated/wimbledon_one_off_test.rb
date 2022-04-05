require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/wimbledon test ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end


school_name_pattern_match = ['wimb*']
source_db = :unvalidated_meter_data

school_names = SchoolFactory.instance.school_file_list(source_db, school_name_pattern_match)

schools = school_names.map do |school_name|
  school = SchoolFactory.instance.load_school(source_db, school_name)
  puts "Got here for #{school_name}"
  puts school.aggregated_heat_meters.amr_data.start_date
  puts school.aggregated_heat_meters.amr_data.end_date
  SchoolFactory.instance.load_school(source_db, school_name)
end
