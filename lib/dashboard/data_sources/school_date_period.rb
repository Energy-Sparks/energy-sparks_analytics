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
