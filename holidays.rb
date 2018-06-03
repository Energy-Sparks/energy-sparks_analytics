# require 'roo'

class SchoolDatePeriod
  attr_reader :type, :name, :start_date, :end_date
  def initialize(type, name, start_date, end_date)
    @type = type
    @name = name
    @start_date = start_date
    @end_date = end_date
  end

  def to_s
    "" << @name << ' (' << start_date.strftime("%a %d %b %Y") << ' to ' << end_date.strftime("%a %d %b %Y") << ')'
  end

  def days
    @end_date - @start_date
  end

  def self.find_period_for_date(date, periods)
    periods.each do |period|
      if date.nil? || period.nil? || period.start_date.nil? || period.end_date.nil?
        raise "Bad date" + date + period
      end
      if date >= period.start_date && date <= period.end_date
        return period
      end
    end
    nil
  end

  def self.find_period_index_for_date(date, periods)
    count = 0
    periods.each do |period|
      if date.nil? || period.nil? || period.start_date.nil? || period.end_date.nil?
        raise "Bad date" + date + period
      end
      if date >= period.start_date && date <= period.end_date
        return count
      end
      count += 1
    end
    nil
  end

  def to_a
    [type, name, start_date, end_date]
  end
end

# holds holiday data as an array of hashes - one hash for each holiday period
class HolidayData < Array
  def add(name, start_date, end_date)
    self.push(SchoolDatePeriod.new(:holiday, name, start_date, end_date))
  end
end

# loads holiday data (from a CSV file), assumes added in date order!
class HolidayLoader
  def initialize(csv_file, holiday_data)
    read_csv(csv_file, holiday_data)
  end

  def read_csv(csv_file, holidays)
    puts "Reading Holiday data from '#{csv_file}'"
    datareadings = Roo::CSV.new(csv_file)
    count = 0
    datareadings.each do |reading|
      name = reading[0]
      start_date = Date.parse reading[1]
      end_date = Date.parse reading[2]
      holidays.add(name, start_date, end_date)
      count += 1
    end
    puts "Read #{count} rows"
    puts "Read #{holidays.length} rows"
  end
end

# contains holidays, plus functionality for determining whether a date is a holiday
class Holidays
  def initialize(holiday_data)
    @holidays = holiday_data
    @cached_holiday_lookup = {}
  end

  def holiday?(date)
    # check cache, as lookup currently loops through list of holidays
    # speeds up this function for 48x365 loopup report by 0.5s (0.6s to 0.1s)
    if @cached_holiday_lookup.key?(date)
      return @cached_holiday_lookup[date]
    end
    holiday = find_holiday(date) != nil
    @cached_holiday_lookup[date] = holiday
    holiday
  end

  def is_weekend(date)
    date.saturday? || date.sunday?
    raise 'Deprecated'
  end

  # returns a hash defining a holiday :name => name, :start_date => start_date, :end_date => end_date} or nil
  def find_holiday(date)
    SchoolDatePeriod.find_period_for_date(date, @holidays)
  end

  def find_summer_holiday_before(date)
    @holidays.reverse.each do |hol|
      # identify summer holiday by length, then month (England e.g. Mon 9 Jul 2018 - Wed 4 Sep 2018  Scotland e.g. Mon 1 Jul 2019 - 13 Aug 2019

      days_in_holiday = (hol.end_date - hol.start_date).to_i
      if days_in_holiday > 4 * 7 && date > hol.end_date
        return hol
      end
    end
    nil
  end

  # returns a list of academic years between 2 dates - iterates backwards from most recent end of summer holiday
  def academic_years(start_date, end_date)
    acy_years = []
    running_date = end_date

    last_summer_hol = find_summer_holiday_before(running_date)
    running_date = last_summer_hol.start_date - 1 # move running date back to day before summer holiday

    until !last_summer_hol.nil do
      previous_summer_hol = find_summer_holiday_before(last_summer_hol.start_date - 1)
      return acy_years if previous_summer_hol.nil?
      return acy_years if previous_summer_hol.end_date < start_date

      year_name = previous_summer_hol.end_date.year.to_s + '/' + last_summer_hol.start_date.year.to_s
      acy_years.push(SchoolDatePeriod.new(:academic_year, year_name, previous_summer_hol.end_date, last_summer_hol.end_date))

      last_summer_hol = find_summer_holiday_before(running_date)
      running_date = last_summer_hol.start_date - 1
    end

    acy_years
  end

  # currently in Class Holidays, but doesn't use holidays, so could be self, mirrors academic_years method above
  def years_to_date(start_date, end_date, move_to_saturday_boundary)
    yrs_to_date = []

    last_date_of_period = end_date
    # move to previous Saturday, so last date a Saturday - better for getting weekends and holidays on right boundaries
    if move_to_saturday_boundary
      last_date_of_period = nearest_previous_saturday(last_date_of_period)
    end

    # iterate backwards creating a year periods until we run out of AMR data

    first_date_of_period = last_date_of_period - 52 * 7 + 1

    while first_date_of_period >= start_date
      # add a new period to the return array
      year_description = "year to " << last_date_of_period.strftime("%a %d %b %y")
      yrs_to_date.push(SchoolDatePeriod.new(:year_to_date, year_description, first_date_of_period, last_date_of_period))

      # move back 52 weeks
      last_date_of_period = first_date_of_period - 1
      first_date_of_period = last_date_of_period - 52 * 7 + 1
    end

    yrs_to_date
  end
end
