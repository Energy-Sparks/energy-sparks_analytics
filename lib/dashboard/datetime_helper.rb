# Date and timer help functions
module DateTimeHelper
  def self.weekend?(date)
    date.saturday? || date.sunday?
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
