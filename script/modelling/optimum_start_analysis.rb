require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  filename = File.join(TestDirectory.instance.log_directory, 'optimum start analysis ' + Time.now.strftime('%H %M') + '.log')
  @logger = Logger.new(filename)
  logger.level = :debug
end

def school_optimum_start_analysis(school)
  return if school.aggregated_heat_meters.nil?

  puts "Processing #{school.name}"

end

school_pattern_match = ['*']

source = :unvalidated_meter_data

school_list = SchoolFactory.instance.school_file_list(source, school_pattern_match)

school_list.sort.each do |school_name|
  school = SchoolFactory.instance.load_school(source, school_name)
  school_optimum_start_analysis(school)
end
