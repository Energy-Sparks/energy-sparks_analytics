require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
require 'tzinfo'

module Logging
  @logger = Logger.new('log/gmt bst timezone analysis ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def summer_winter_time_transition_dates(back_years = 5)
  mid_summer = Date.new(Date.today.year, 6, 21)
  tz = TZInfo::Timezone.get('Europe/London')

  mid_summer_dates = (0..back_years).to_a.map { |year_offset| mid_summer - 365 * year_offset }

  mid_summer_dates.map do |date|
    period = tz.periods_for_local(date.to_time)[0]
    [
      period.local_start.to_date,
      period.local_end.to_date
    ]
  end.flatten.sort.uniq.reverse.drop(1).reverse
end


def school_days_from_offset(school, transition_date, days: 5, direction: 1)
  school_day_dates= []
  date = transition_date
  while school_day_dates.length < days
    school_day_dates.push(date) if school.holidays.occupied?(date)
    date += direction
  end
  school_day_dates.sort
end

def transition_kwh(meter, date)
  kwh_x48 = meter.amr_data.one_days_data_x48(date)
  sorted_kwh_x48 = kwh_x48.sort
  peak_kwhs = sorted_kwh_x48.last(4).sum / 4.0
  baseload_kwhs = sorted_kwh_x48.first(4).sum / 4.0
  (peak_kwhs + baseload_kwhs) / 2.0
end

def first_transition_hh_index(meter, date, kwh)
  kwh_x48 = meter.amr_data.one_days_data_x48(date)
  (0..47).each do |hh_index|
    return hh_index if kwh_x48[hh_index] > kwh
  end
  nil
end

def last_transition_hh_index(meter, date, kwh)
  kwh_x48 = meter.amr_data.one_days_data_x48(date).reverse
  (0..47).each do |hh_index|
    return 47 - hh_index if kwh_x48[hh_index] > kwh
  end
  nil
end

def average_start_time(meter, dates)
  hh_times = dates.map do |date|
    kwh = transition_kwh(meter, date)
    first_transition_hh_index(meter, date, kwh)
  end.compact
  1.0 * hh_times.sum / hh_times.length
end

def average_end_time(meter, dates)
  hh_times = dates.map do |date|
    kwh = transition_kwh(meter, date)
    last_transition_hh_index(meter, date, kwh)
  end.compact
  1.0 * hh_times.sum / hh_times.length
end

def analyse_meter(school, meter, transition_dates)
  puts "#{school.name} #{meter.mpxn}"
  transition_shift = {}
  transition_dates.each do |transition_date|
    if meter.amr_data.start_date < transition_date - 10 &&
       meter.amr_data.end_date > transition_date + 10
      dates_before = school_days_from_offset(school, transition_date)

      before_time = average_start_time(meter, dates_before)
      dates_after = school_days_from_offset(school, transition_date, direction: -1)#

      after_time = average_start_time(meter, dates_after)
      transition_shift[transition_date] = before_time - after_time
    else
      transition_shift[transition_date] = nil
    end
  end
  transition_shift
end

def save_to_csv(transition_dates, data)
  filename = "Results\\analyse meter bst-gmt times.csv"
  puts "Saving to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['school', 'mpxn', transition_dates].flatten
    data.each do |school_name, meters|
      meters.each do |mpxn, date_to_offset|
        csv << [school_name, mpxn, date_to_offset.values].flatten
      end
    end
  end
end

transition_dates = summer_winter_time_transition_dates

school_name_pattern_match = ['*'] 
source_db = :unvalidated_meter_data
school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)
data = {}

school_names.each do |school_name|
  begin
    school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)
    electric_meters = school.electricity_meters # real_meters2.select { |meter| meter.fuel_type == :electricity }
    electric_meters.each do |meter|
      data[school_name] ||= {}
      data[school_name][meter.mpxn] = analyse_meter(school, meter, transition_dates)
    end
  rescue => e
    puts "#{school_name} #{e.message}"
  end
end

ap data

save_to_csv(transition_dates, data)
