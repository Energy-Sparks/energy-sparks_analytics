# Date and timer help functions

# time of day (differentiates between 00:00 and 24:00)
class TimeOfDay < Time
  def initialize(hour, minutes)
    if hour.nil? || minutes.nil? || hour < 0 || hour > 24 || minutes < 0 || minutes >= 60 || (hour == 24 && minutes != 0)
      raise EnergySparksUnexpectedStateException.new("Unexpected time of day setting #{hour}:#{minutes}")
    end
    super(1970, 1, 1, hour, minutes, 0)
  end

  def to_s
    if day == 1
      self.strftime('%H:%M')
    elsif day == 2 && hour == 0
      self.strftime('24:%M')
    else
      '??:??'
    end
  end
end

# time of year - so only month and day of month
class TimeOfYear < Time
  include Comparable
  def initialize(month, day_of_month)
    super(1970, month, day_of_month, 0, 0, 0)
  end

  def to_s
    self.strftime('%d %b')
  end

  def <=>(other)
    other.class == self.class && [month, day] <=> [other.month, other.day]
  end
end

module DateTimeHelper
  def self.weekend?(date)
    date.saturday? || date.sunday?
  end

  # returns the next weekday 0 = Sunday.....6 = Saturday for date, if date = weekday then return date
  def next_weekday(date, wday)
    days_to_wday = date.wday - wday
    if date.wday < wday
      date = date + (wday - date.wday)
    elsif date.wday > wday
      date = date + (7 - (date.wday - wday))
    else
      date
    end
  end

  def self.datetime(date, halfhour_index)
    hour = (halfhour_index / 2).round
    minute = halfhour_index % 2 == 1 ? 30 : 0

    # Time is too slow on Windows, order of magnitude slower than DateTime
    DateTime.new(date.year, date.month, date.day, hour, minute, 0)
  end

  def self.date_and_half_hour_index(datetime)
    date = Date.new(datetime.year, datetime.month, datetime.day)
    index = datetime.hour * 2 + (datetime.minute % 30)
    [date, index]
  end

  def self.time_to_date_and_half_hour_index(time)
    date = Date.new(time.year, time.month, time.day)
    index = time.hour * 2 + (time.min % 30)
    [date, index]
  end
end
