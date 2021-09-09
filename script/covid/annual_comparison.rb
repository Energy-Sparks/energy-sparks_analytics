# adhoc COVID calculations
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/adhoc covid annual analysis ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def school_factory
  $SCHOOL_FACTORY ||= SchoolFactory.new
end

def unique_years(results, fuel_type_type, data_type_type)
  years = []
  results.each do |school_name, school_data|
    school_data.each do |fuel_type, fuel_type_data|
      fuel_type_data.each do |data_type, years_data|
        years.push(years_data.keys) if fuel_type_type == fuel_type && data_type_type == data_type
      end
    end
  end
  years.flatten.uniq.sort_by { |v| v.first }
end

def save_csv(results, funding_status, fuel_type, data_type)
  filename = "./Results/annual #{fuel_type} #{data_type}.csv"
  puts "Saving results to #{filename}"
  
  years = unique_years(results, fuel_type, data_type)

  CSV.open(filename, 'w') do |csv|
    csv << ['school name', 'funding status', years].flatten
    results.each do |school_name, school_data|

      next if school_data[fuel_type].nil? || school_data[fuel_type][data_type].nil?

      data = school_data[fuel_type][data_type]
      year_data_with_nulls = years.map { |year_range| data[year_range] }

      csv << [school_name, funding_status[school_name], year_data_with_nulls].flatten
    end
  end
end

def calculate_years(start_date, end_date)
  years = ((end_date - start_date + 1) / 365.0).to_i
  year_date_ranges = []

  while end_date - 364 >= start_date
    year_date_ranges.push((end_date - 364)..end_date)
    end_date -= 365
  end
  year_date_ranges.reverse
end

def analyse_school(school, fuel_type, adjusted_heating, data_type, somerset_late_days = 4)
  meter = school.aggregate_meter(fuel_type)
  return {} if meter.nil?
  return {} if meter.amr_data.end_date + somerset_late_days < DateTimeHelper.first_day_of_month(Date.today)

  annual_kwhs = {}

  year_date_ranges = calculate_years(meter.amr_data.start_date, meter.amr_data.end_date)

  return {} if year_date_ranges.length < 1

  if adjusted_heating
    splitter = HotWaterHeatingSplitter.new(school, fault_tolerant_model_dates: true)
    adjusted = splitter.degree_day_adjust_heating(year_date_ranges, meter: meter, adjustment_method: :average, data_type: data_type)
    adjusted.transform_keys{ |k| k.first.year..k.last.year }
  else
    year_date_ranges.map do |year_date_range|
      end_date = [year_date_range.last, meter.amr_data.end_date].min
      [
        year_date_range.first.year..year_date_range.last.year,
        annual_kwh(meter, year_date_range.first, end_date, adjusted_heating, data_type)
      ]
    end.to_h
  end
end

def annual_kwh(meter, start_date, end_date, adjusted_heating, data_type)
  if meter.fuel_type == :electricity || !adjusted_heating
    meter.amr_data.kwh_date_range(start_date, end_date, data_type)
  else
    meter.amr_data.kwh_date_range(start_date, end_date, data_type)
  end
end

def carbon_intensities(school_data)
  school_data.each do |fuel_type, annual_kwh_and_co2|
    next if annual_kwh_and_co2[:kwh].nil?

    annual_kwh_and_co2[:kwh].each do |year_range, kwh|
      annual_kwh_and_co2[:co2_per_kwh] ||= {}
      annual_kwh_and_co2[:co2_per_kwh] [year_range] = (annual_kwh_and_co2[:co2][year_range] / kwh).round(3)
    end
  end
end

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data
today = Date.new(2021, 9, 6)

funding_status = {}
annual_kwhs = {}

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

schools = school_names.map do |school_name|
  school = school_factory.load_or_use_cached_meter_collection(:name, school_name, source_db)

  %i[co2 kwh].each do |data_type|
    %i[electricity gas storage_heater].each do |fuel_type|
      data = analyse_school(school, fuel_type, false, data_type)

      unless data.empty?
        annual_kwhs[school.name] ||= {}
        annual_kwhs[school.name][fuel_type] ||= {}
        annual_kwhs[school.name][fuel_type][data_type] = data
        funding_status[school.name] = school.funding_status
        if %i[gas storage_heater].include?(fuel_type)
          adjusted_data_type_key = "adjusted_heating_#{data_type}".to_sym
          annual_kwhs[school.name][fuel_type][adjusted_data_type_key] = analyse_school(school, fuel_type, true, data_type)
        end
      end
    end
  end
rescue => e
  puts e.message
  puts e.backtrace
end

annual_kwhs.each do |school_name, school_data|
  carbon_intensities(school_data)
end
ap annual_kwhs

save_csv(annual_kwhs, funding_status, :electricity, :co2)
save_csv(annual_kwhs, funding_status, :electricity, :kwh)
save_csv(annual_kwhs, funding_status, :electricity, :co2_per_kwh)
save_csv(annual_kwhs, funding_status, :gas,         :adjusted_heating_co2)
save_csv(annual_kwhs, funding_status, :gas,         :adjusted_heating_kwh)
save_csv(annual_kwhs, funding_status, :gas,         :co2_per_kwh)
