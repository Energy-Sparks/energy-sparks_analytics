# adhoc COVID calculations
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/adhoc covid ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def school_factory
  $SCHOOL_FACTORY ||= SchoolFactory.new
end

def unique_years(results)
  years = []
  results.each do |school_name, school_data|
    school_data.each do |fuel_type, years_data|
      years = [years + years_data.keys ].flatten.uniq
    end
  end
  years.sort_by { |year_range| year_range.first }
end

def save_csv(results, funding_status)
  filename = './Results/annual by fuel consumptions.csv'
  uy = unique_years(results)

  puts "Saving results to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['school name', 'funding status', 'fuel type', 'can analyse',  uy].flatten
    results.each do |school_name, fuel_type_years|
      fuel_type_years.each do |fuel_type, annual_kwhs|
        annual_kwh_by_year = uy.map { |y_y| annual_kwhs[y_y] }
        csv << [school_name, funding_status[school_name], fuel_type, can_analyse?(fuel_type, annual_kwhs), annual_kwh_by_year].flatten
      end
    end
  end
end

def can_analyse?(fuel_type, annual_kwhs)
  case fuel_type
  when :electricity
    annual_kwhs.length >= 2
  when :gas, :storage_heater
    annual_kwhs.length >= 2
  end
end

def years_history(meter, end_date)
  return {} if meter.amr_data.end_date + 30 < end_date # non-recent meter data

  end_date = meter.amr_data.end_date

  years = {}
  while end_date - 365 >= meter.amr_data.start_date
    start_date = end_date - 365 + 1
    years[start_date.year..end_date.year] = meter.amr_data.kwh_date_range(start_date, end_date)
    end_date = start_date - 1
  end
  years
end

def calculate_energy_history(school, today)
  fuel_types = school.fuel_types(false, true)

  fuel_types.map do |fuel_type|
    meter = school.aggregate_meter(fuel_type)
    [
      fuel_type,
      years_history(meter, today)
    ]
  end.to_h
end

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data
today = Date.new(2021, 9, 6)

results = {}
funding_status = {}

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

schools = school_names.map do |school_name|
  school = school_factory.load_or_use_cached_meter_collection(:name, school_name, source_db)

  results[school.name] = calculate_energy_history(school, today)
  funding_status[school.name] = school.funding_status
rescue => e
  puts e.message
  puts e.backtrace
end

ap results

save_csv(results, funding_status)
