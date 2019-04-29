require_relative '../data_sources/school_date_period' # PH(03Jul2018) - James this probably needs fixing, there is a ruby loading order issue
# holds holiday data as an array of hashes - one hash for each holiday period
class HolidayData < Array
  include Logging

  def add(title, start_date, end_date)
    self.push(SchoolDatePeriod.new(:holiday, title, start_date, end_date))
  end
end

# loads holiday data (from a CSV file), assumes added in date order!
class HolidayLoader
  include Logging

  def initialize(csv_file, holiday_data)
    read_csv(csv_file, holiday_data)
  end

  def read_csv(csv_file, holidays)
    logger.debug "Reading Holiday data from '#{csv_file}'"
    datareadings = Roo::CSV.new(csv_file)
    count = 0
    datareadings.each do |reading|
      title = reading[0]
      start_date = Date.parse reading[1]
      end_date = Date.parse reading[2]
      holidays.add(title, start_date, end_date)
      count += 1
    end
    logger.debug "Read #{count} rows"
    logger.debug "Read #{holidays.length} rows"
  end
end

# contains holidays, plus functionality for determining whether a date is a holiday
class Holidays
  include Logging

  def initialize(holiday_data)
    @holidays = holiday_data
    @cached_holiday_lookup = {} # for speed,
  end

  def holiday?(date)
    !holiday(date).nil?
  end

  def occupied?(date)
    !weekend?(date) && !holiday?(date)
  end

  def last
    @holidays.last
  end

  # returns a holiday period corresponding to a date, nil if not a date
  def holiday(date)
    # check cache, as lookup currently loops through list of holidays
    # speeds up this function for 48x365 loopup report by 0.5s (0.6s to 0.1s)
    if @cached_holiday_lookup.key?(date)
      return @cached_holiday_lookup[date]
    end
    @cached_holiday_lookup[date] = find_holiday(date)
    @cached_holiday_lookup[date]
  end

  def is_weekend(date)
    date.saturday? || date.sunday?
    raise 'Deprecated'
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  # returns a hash defining a holiday :title => title, :start_date => start_date, :end_date => end_date} or nil
  def find_holiday(date)
    SchoolDatePeriod.find_period_for_date(date, @holidays)
  end

  def find_next_holiday(date, max_days_search = 100)
    (0..max_days_search).each do |days|
      period = SchoolDatePeriod.find_period_for_date(date + days, @holidays)
      return period unless period.nil?
    end
    nil
  end

  def same_holiday_previous_year(this_years_holiday_period, max_days_search = 365 + 100)
    this_years_holiday_mid_date = this_years_holiday_period.start_date + (this_years_holiday_period.days / 2).floor
    this_years_holiday_type = type(this_years_holiday_mid_date) 
    # start 200 days back, the only real concern is to mis Easter which moves by up to ~40 days
    (200..max_days_search).each do |num_days_offset_backwards|
      date = this_years_holiday_period.start_date - num_days_offset_backwards
      last_years_holiday_period = find_holiday(date)
      unless last_years_holiday_period.nil?
        last_years_holiday_mid_date = last_years_holiday_period.start_date + (last_years_holiday_period.days / 2).floor
        last_years_holiday_type = type(last_years_holiday_mid_date)
        return last_years_holiday_period if this_years_holiday_type == last_years_holiday_type
      end
    end
    nil
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

  def find_all_summer_holidays_date_range(start_date, end_date)
    summer_holidays = []
    summer_holiday = find_summer_holiday_before(end_date)
    while !summer_holiday.nil? do
      summer_holidays.push(summer_holiday)
      summer_holiday = find_summer_holiday_before(summer_holiday.start_date - 1)
    end
    summer_holidays
  end

  def find_summer_holiday_after(date)
    @holidays.each do |hol|
      # identify summer holiday by length, then month (England e.g. Mon 9 Jul 2018 - Wed 4 Sep 2018  Scotland e.g. Mon 1 Jul 2019 - 13 Aug 2019

      days_in_holiday = (hol.end_date - hol.start_date + 1).to_i
      if days_in_holiday > 4 * 7 && date < hol.start_date
        return hol
      end
    end
    nil
  end

  # iterate backwards to find nth school week before date, skipping holidays
  # last week = 0, previous school week = -1, iterates on Sunday-Saturday boundary
  def nth_school_week(asof_date, nth_week_number, min_days_in_school_week = 3, min_date = nil)
    raise EnergySparksBadChartSpecification.new("Badly specified nth_school_week #{nth_week_number} must be zero or negative") if nth_week_number > 0
    raise EnergySparksBadChartSpecification.new("Badly specified min_days_in_school_week #{min_days_in_school_week} must be > 0") if min_days_in_school_week <= 0
    limit = 2000
    week_count = nth_week_number.magnitude
    saturday = asof_date.saturday? ? asof_date : nearest_previous_saturday(asof_date)
    loop do
      break if !min_date.nil? && saturday <= min_date
      monday = saturday - 5
      friday = saturday - 1
      holiday_days_in_week = holidaydays_in_range(monday, friday)
      week_count -= 1 unless holiday_days_in_week > (5 - min_days_in_school_week)
      break if week_count < 0
      saturday = saturday - 7
      limit -= 1
      raise EnergySparksUnexpectedStateException.new('Gone too many times around loop looking for school weeks, not sure why error has occurred') if limit <= 0
    end
    [saturday - 6, saturday, week_count]
  end

  # doesn't really fit here, but for the moment can't think of a better place
  # mix of class and instance 'holiday' access isn't ideal
  def self.periods_in_date_range(start_date, end_date, period_type, holidays)
    case period_type
    when :year
      ((end_date - start_date + 1) / 365.0).floor
    when :academicyear
      academic_years(start_date, end_date).length
    when :week
      ((end_date - start_date + 1) / 7.0).floor
    when :day, :datetime
      end_date - start_date + 1
    when :school_week
      _sunday, _saturday, week_count = holidays.nth_school_week(end_date, -1000, 3, start_date)
      1000 - week_count
    else
      throw EnergySparksUnexpectedStateException.new("Unsupported period type #{period_type} for periods_in_date_range request")
    end
  end

  # was originally included in ActiveSupport code base, may be lost in rails integration
  # not sure whether it includes current Saturday, assume not, so if date is already a Saturday, returns date - 7
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
      AcademicYear.new(previous_summer_hol.end_date + 1, last_summer_hol.end_date)
      acy_years.push(AcademicYear.new(previous_summer_hol.end_date + 1, last_summer_hol.end_date, @holidays))

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


  class AcademicYear < SchoolDatePeriod
    include Logging

    attr_reader :holidays_in_year
    def initialize(start_date, end_date, full_holiday_schedule)
      year_name = start_date.year.to_s + '/' + end_date.year.to_s
      super(:academic_year, year_name, start_date, end_date)
      @holidays_in_year = find_holidays_in_year(full_holiday_schedule)
    end

    def find_holidays_in_year(full_holiday_schedule)
      hols = []
      full_holiday_schedule.each do |hol|
        if hol.start_date >= start_date && hol.end_date <= end_date
          hols.push(hol)
        end
      end
      hols
    end
  end

  def academic_year(date)
    summer_hol_before = find_summer_holiday_before(date)
    summer_hol_after = find_summer_holiday_after(date)
    if summer_hol_before.nil? || summer_hol_after.nil?
      logger.debug "Warning: unable to find academic year for date #{date}"
      nil
    else
      acy_year = AcademicYear.new(summer_hol_before.end_date + 1, summer_hol_after.end_date, @holidays)
      # logger.debug "Found academic year for date #{date} - year from #{acy_year.start_date} #{acy_year.end_date}"
      acy_year
    end
  end

  # returns current academic year if n = 0, next if n = 1, 2 before if n = -2
  def nth_academic_year_from_date(n, date, raise_exception = true)
    this_year = academic_year(date)
    raise EnergySparksUnexpectedStateException.new("Cannnot find current academic year for date #{date}") if this_year.nil?
    # slightly crude way of doing this
    mid_point_of_year = this_year.start_date + 180
    day_in_middle_of_wanted_year = mid_point_of_year + n * 365
    wanted_year = academic_year(day_in_middle_of_wanted_year)
    raise EnergySparksUnexpectedStateException.new("Cannnot find #{n}th academic year for date #{date}") if wanted_year.nil? && raise_exception
    wanted_year
  end

  def find_holiday_in_academic_year(academic_year, holiday_type)
    hol = find_holiday_in_academic_year_private(academic_year, holiday_type)
    if hol.nil?
      logger.debug "Unable to find holiday of type #{holiday_type} in academic year #{academic_year.start_date} to #{academic_year.end_date}"
    end
    hol
  end

  # for holidays types see code
  def find_holiday_in_academic_year_private(academic_year, holiday_type)
    academic_year.holidays_in_year.each do |hol|
      case holiday_type
      when :xmas
        return hol if hol.start_date.month == 12 && hol.days > 5
      when :spring_half_term
        return hol if (hol.start_date.month == 2 || (hol.start_date.month == 1 && hol.end_date.month == 2)) && hol.days > 3
      when :easter
        return hol if (hol.start_date.month == 3 || hol.start_date.month == 4) && hol.days > 4
      when :mayday
        return hol if hol.start_date.month == 5 && hol.days <= 2
      when :summer_half_term
        return hol if hol.start_date.month == 5 && hol.days > 2
      when :summer
        return hol if (hol.start_date.month == 6 || hol.start_date.month == 7) && hol.days > 10
      when :autumn_half_term
        return hol if hol.start_date.month == 10 && hol.days > 3
      else
        raise EnergySparksUnexpectedStateException.new("Unknown holiday type #{holiday_type}")
      end
    end
    nil
  end

  # returns which holiday this is, not self as may eventually
  # have to reference its own holiday schedule
  # would be best if list were an enumeration, but these aren't supported outside rails
  def type(date)
    case date.month
    when 1, 12
      :xmas
    when 2
      :spring_half_term
    when 3, 4
      :easter
    when 5
      if date.day < 15
        :mayday
      else
        :summer_half_term
      end
    when 7, 8, 9
      :summer
    when 10, 11
      :autumn_half_term
    else
      nil
    end
  end
end
