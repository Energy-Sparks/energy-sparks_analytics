class SchoolDatePeriod
  include Logging

  attr_reader :type, :title, :start_date, :end_date, :calendar_event_type_id
  def initialize(type, title, start_date, end_date)
    @type = type
    @title = title
    @start_date = start_date
    @end_date = end_date
    @calendar_event_type_id = @calendar_event_type_id
  end

  def to_s
    "" << @title << ' (' << start_date.strftime("%a %d %b %Y") << ' to ' << end_date.strftime("%a %d %b %Y") << ')'
  end

  def days
    (@end_date - @start_date + 1).to_i
  end

  def self.year_to_date(type, title, end_date, limit_start_date = nil)
    # use 364 = 52 weeks rather than 365, as works better with weekly aggregation etc.
    start_date = limit_start_date.nil? ? end_date - 364 : [end_date - 364, limit_start_date].max
    SchoolDatePeriod.new(type, title, start_date, end_date)
  end

  def dates
    (start_date..end_date).to_a
  end

  def self.matching_dates_in_period_to_day_of_week_list(period, list_of_days_of_week)
    (period.start_date..period.end_date).to_a.select { |date| list_of_days_of_week.include?(date.wday) }
  end

  def self.merge_two_periods(period_1, period_2)
    if period_1.start_date >= period_2.start_date && period_1.end_date >= period_2.end_date
      SchoolDatePeriod.new(period_1.type, period_1.title + 'merged', period_2.start_date, period_1.end_date)
    elsif period_2.start_date >= period_1.start_date && period_2.end_date >= period_1.end_date
      SchoolDatePeriod.new(period_2.type, period_2.title + 'merged', period_1.start_date, period_2.end_date)
    else
      raise EnergySparksUnexpectedStateException.new('Expected School Period merge request for overlapping date ranges')
    end
  end

  def self.find_period_for_date(date, periods)
    period = nil
    if periods.length > 1 && periods[0].start_date < periods[1].start_date
      period = periods.bsearch {|p| date < p.start_date ? -1 : date > p.end_date ? 1 : 0 }
    else  # reverse sorted array
      period = periods.bsearch {|p| date < p.start_date ? 1 : date > p.end_date ? -1 : 0 }
    end
    period
  end


  def self.find_period_for_date_deprecated(date, periods)
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

  def self.info_compact(periods, columns = 3, with_count = true, date_format = '%a %d%b%y')
    periods.each_slice(columns).to_a.each do |group_period|
      line = '  '
      group_period.each do |period|
        d1 = period.start_date.strftime(date_format)
        d2 = period.end_date.strftime(date_format)
        length = period.end_date - period.start_date + 1
        line += " #{d1} to #{d2}" + (with_count ? sprintf(' * %3d', length) : '')
      end
      Logging.logger.info line
    end
  end

  def to_a
    [type, title, start_date, end_date]
  end
end
