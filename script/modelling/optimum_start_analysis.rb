require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  filename = File.join(TestDirectory.instance.log_directory, 'optimum start analysis ' + Time.now.strftime('%H %M') + '.log')
  @logger = Logger.new(filename)
  logger.level = :debug
end

def save_csv(results)
  filename = File.join(TestDirectory.instance.results_directory('modelling'), 'optimum start.csv')
  
  puts "Writing results to #{filename}"

  CSV.open(filename, 'w') do |csv|
    csv << ['School name', results.values.first.keys].flatten
    results.each do |name, d|
      next if d.nil?
      csv << [name, d.values].flatten
    end
  end
end

def calc_heating_model(meter)
  start_date = [meter.amr_data.end_date - 365, meter.amr_data.start_date].max
  end_date = meter.amr_data.end_date
  period = SchoolDatePeriod.new(:analysis, 'Up to a year', start_date, end_date)
  meter.heating_model(period)
rescue
  nil
end

def school_optimum_start_analysis(school)
  if school.aggregated_heat_meters.nil?
    puts "No gas data for #{school.name}"
    return
  end

  puts "Processing #{school.name}"
  heating_model = calc_heating_model(school.aggregated_heat_meters)

  if heating_model.nil?
    puts "Model calculation failed for #{school.name}"
    return
  end

  heating_model.optimum_start_analysis
end

school_pattern_match = ['*']
results = {}

source = :unvalidated_meter_data

school_list = SchoolFactory.instance.school_file_list(source, school_pattern_match)

school_list.sort.each do |school_name|
  school = SchoolFactory.instance.load_school(source, school_name)
  results[school.name] = school_optimum_start_analysis(school)
end

ap results

save_csv(results)
