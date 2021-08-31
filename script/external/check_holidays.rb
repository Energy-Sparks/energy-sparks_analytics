require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/holiday schedule integrity ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

school_name_pattern_match = ['Wimble*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

puts '=' * 80
puts 'Checking the integrity of the holiday schedule'

issues_by_school = {}

school_names.each do |school_name|
  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  puts '-' * 80
  puts school.name

  issues_by_school[school.name] = Holidays.check_school_holidays(school)
end

ap issues_by_school.select { |k, v| !v.empty? }
