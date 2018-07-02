# holds holiday data as an array of hashes - one hash for each holiday period
class HolidayData < Array
  def add(title, start_date, end_date)
    self.push(SchoolDatePeriod.new(:holiday, title, start_date, end_date))
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
      title = reading[0]
      start_date = Date.parse reading[1]
      end_date = Date.parse reading[2]
      holidays.add(title, start_date, end_date)
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

  # returns a hash defining a holiday :title => title, :start_date => start_date, :end_date => end_date} or nil
  def find_holiday(date)
    SchoolDatePeriod.find_period_for_date(date, @holidays)
  end

  def find_summer_holiday_before(date)
    @holidays.reverse.each do |hol|
      # identify summer holiday by length, then month (England e.g. Mon 9 Jul 2018 - Wed 4 Sep 2018  Scotland e.g. Mon 1 Jul 2019 - 13 Aug 2019

      days_in_holiday = (hol.end_date - hol.start_date + 1).to_i
      if days_in_holiday > 4 * 7 && date > hol.end_date
        return hol
      end
    end
    nil
  end
  
  # iterate backwards to find nth school week before date, skipping holidays
  # last week = 0, previous school week = -1, iterates on Sunday-Saturday boundary
  def nth_school_week(asof_date, nth_week_number, min_days_in_school_week = 3)
    raise EnergySparksBadChartSpecification.new("Badly specified nth_school_week #{nth_week_number} must be zero or negative") if nth_week_number > 0
    raise EnergySparksBadChartSpecification.new("Badly specified min_days_in_school_week #{min_days_in_school_week} must be > 0") if min_days_in_school_week <= 0
    limit = 2000
    week_count = nth_week_number.magnitude
    saturday = asof_date.saturday? ? asof_date : nearest_previous_saturday(asof_date)
    loop do
      monday = saturday - 5
      friday = saturday - 1
      holiday_days_in_week = holidaydays_in_range(monday, friday)
      week_count -= 1 unless holiday_days_in_week > (5 - min_days_in_school_week)
      break if week_count < 0
      saturday = saturday - 7
      limit -= 1
      raise EnergySparksUnexpectedStateException.new('Gone too many times around loop looking for school weeks, not sure why error has occurred') if limit <= 0
    end
    [saturday - 6, saturday]
  end

  # was originally included in ActiveSupport code base, may be lost in rails integration
  # not sure whethe it includes current Saturday, assume not, so if date is already a Saturday, returns date - 7
  def nearest_previous_saturday(date)
    date - (date.wday + 1)
  end

  def holidaydays_in_range(start_date, end_date)
    count = 0
    (start_date..end_date).each do |date|
      count += 1 if holiday?(date)
    end
    count
  end

  # returns a list of academic years between 2 dates - iterates backwards from most recent end of summer holiday
  def academic_years(start_date, end_date)
    acy_years = []

    last_summer_hol = find_summer_holiday_before(end_date)

    until last_summer_hol.nil? do
      previous_summer_hol = find_summer_holiday_before(last_summer_hol.start_date - 1)
      return acy_years if previous_summer_hol.nil?
      return acy_years if previous_summer_hol.end_date < start_date

      year_name = previous_summer_hol.end_date.year.to_s + '/' + last_summer_hol.start_date.year.to_s
      acy_years.push(SchoolDatePeriod.new(:academic_year, year_name, previous_summer_hol.end_date + 1, last_summer_hol.end_date))

      last_summer_hol = previous_summer_hol
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
