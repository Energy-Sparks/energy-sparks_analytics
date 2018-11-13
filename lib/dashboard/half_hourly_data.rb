require 'csv'

# 'base' class used for holding hald hourly data typical to schools' energy analysis
# generally data held in derived classes e.g. temperatures, solar insolence, AMR data
# hash of date => 48 x float values
class HalfHourlyData < Hash
  include Logging

  attr_reader :type, :validated
  def initialize(type)
    @min_date = Date.new(4000, 1, 1)
    @max_date = Date.new(1000, 1, 1)
    @validated = false
    @type = type
    @cache_days_totals = {} # speed optimisation cache[date] = total of 48x 1/2hour data
  end

  def add(date, half_hourly_data_x48)
    set_min_max_date(date)

    self[date] = half_hourly_data_x48

    data_count = validate_data(half_hourly_data_x48)
    @cache_days_totals.delete(date)

    if data_count != 48
      logger.debug "Missing data: #{date}: only #{data_count} of 48"
    end
  end

  def average(date)
    self[date].inject{ |sum, el| sum + el }.to_f / self[date].size
  end

  def average_in_date_range(start_date, end_date)
    if start_date < self.start_date || end_date > self.end_date
      return nil # NAN blows up write_xlsx
    end
    total = 0.0
    (start_date..end_date).each do |date|
      total += average(date)
    end
    total / (end_date - start_date + 1)
  end

  def missing_dates
    dates = []
    (@min_date..@max_date).each do |date|
      if !self.key?(date)
        dates.push(date)
      end
    end
    dates
  end

  def validate_data(half_hourly_data_x48)
    total = 0
    data_count = 0
    (0..47).each do |i|
      if half_hourly_data_x48[i].is_a?(Float) || half_hourly_data_x48[i].is_a?(Integer) || half_hourly_data_x48[i].is_a?(BigDecimal)
        total = total + half_hourly_data_x48[i]
        data_count = data_count + 1
      end
    end

    data_count
  end

  # first and last dates maintained manually as the data is held in a hash for speed of access by date
  def set_min_max_date(date)
    if date < @min_date
      @min_date = date
    end
    if date > @max_date
      @max_date = date
    end
  end

  # half_hour_index is 0 to 47, i.e. the index for the half hour within the day
  def data(date, half_hour_index)
    self[date][half_hour_index] if self[date]
  end

  def one_day_total(date)
    unless @cache_days_totals.key?(date) # performance optimisation, needs rebenchmarking to check its an actual speedup
      if self[date].nil?
        logger.debug "Error: missing data for #{self.class.name} on date #{date} returning zero"
        return 0.0
      end
      total = self[date].inject(:+)
      @cache_days_totals[date] = total
      return total
    end
    @cache_days_totals[date]
  end

  def total_in_period(start_date, end_date)
    total = 0.0
    (start_date..end_date).each do |date|
      total += one_day_total(date)
    end
    total
  end

  def start_date
    @min_date
  end

  def end_date
    @max_date
  end

  def set_min_date(min_date)
    @min_date = min_date
  end

  def set_max_date(max_date)
    @max_date = max_date
  end

  def set_validated(valid)
    @validated = valid
  end

  # probably slow
  def all_dates
    self.keys.sort
  end

  # returns an array of DatePeriod - 1 for each acedemic years, with most recent year first
  def academic_years(holidays)
    logger.warn "Warning: depricated from this location please use version in Class Holidays"
    holidays.academic_years(start_date, end_date)
  end

  def nearest_previous_saturday(date)
    while date.wday != 6
      date -= 1
    end
    date
  end
end
