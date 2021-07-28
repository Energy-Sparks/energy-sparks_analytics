require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/display energy certificates ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def month_start_dates
  [
    Date.new(2020,  7, 1),
    Date.new(2020,  8, 1),
    Date.new(2020,  9, 1),
    Date.new(2020, 10, 1),
    Date.new(2020, 11, 1),
    Date.new(2020, 12, 1),
    Date.new(2021,  1, 1),
    Date.new(2021,  2, 1),
    Date.new(2021,  3, 1),
    Date.new(2021,  4, 1),
    Date.new(2021,  5, 1),
    Date.new(2021,  6, 1)
  ]
end

def month_date_ranges
  @month_date_ranges ||= month_start_dates.map { |d1| d1..DateTimeHelper.last_day_of_month(d1) }
end

def year_start_date; month_date_ranges.first.first end
def year_end_date; month_date_ranges.last.last end


def monthly_kwhs(school, fuel_type)
  meter = school.aggregate_meter(fuel_type)
  return {} if meter.nil? || meter.amr_data.start_date > year_start_date || meter.amr_data.end_date < year_end_date

  data = {}
  count = {}

  month_date_ranges.each do |month_date_range|
    data[month_date_range] = { schoolday: 0.0, weekend: 0.0, holiday: 0.0 }
    count[month_date_range] = { schoolday: 0, weekend: 0, holiday: 0 }
    month_date_range.each do |date|
      daytype = school.holidays.day_type(date)
      data[month_date_range][daytype]  += meter.amr_data.one_day_kwh(date)
      count[month_date_range][daytype] += 1
    end
  end

  [data, count]
end

def calculate_average_monthly_percent_by_daytype(school, fuel_type)
  data, count = monthly_kwhs(school, fuel_type)
  average_daytype = average_annual_kwh_by_daytype(data, count)

  average = {}
  data.each_key do |month_date_range|
    average[month_date_range] = { schoolday: 0.0, weekend: 0.0, holiday: 0.0 }
  end

  %i[schoolday weekend holiday].each do |daytype|
    data.each do |month_range, months_data|
      avg = average_daytype[daytype]
      average[month_range][daytype] = (months_data[daytype] / count[month_range][daytype]) / avg
    end
  end

  average
end

def average_annual_kwh_by_daytype(data, count)
  average = {}
  %i[schoolday weekend holiday].each do |daytype|
    s = 0.0
    c = 0.0
    data.each do |month_range, months_data|
      s += months_data[daytype]
      c += count[month_range][daytype]
    end
    average[daytype] = c > 0 ? s / c : 0.0
  end
  average
end

def sub_nil_nan(arr)
  arr.map { |v| v.nan? ? nil : v }
end

def save_csv(data)
  filename = './Results/targeting_and_tracking_seasonality.csv'
  puts "Saving results to #{filename}"
  CSV.open(filename, 'w') do |csv|
    months = month_date_ranges.map { |dr| dr.first.strftime('%b %Y') }
    csv << ['School', 'School days', months, 'Weekends', months, 'Holidays', months].flatten
    data.each do |school_name, years_data|
      row = [school_name] +
            [nil] +
            sub_nil_nan(years_data.values.map{ |months| months[:schoolday] }) +
            [nil] +
            sub_nil_nan(years_data.values.map{ |months| months[:weekend] }) +
            [nil] +
            sub_nil_nan(years_data.values.map{ |months| months[:holiday] })
      csv << row.flatten
    end
  end
end

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

ap school_names
data = {}

school_names.each do |school_name|
  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  data[school_name] = calculate_average_monthly_percent_by_daytype(school, :electricity)
end

save_csv(data)
