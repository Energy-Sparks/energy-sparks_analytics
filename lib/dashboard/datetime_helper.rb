# Date and timer help functions
module DateTimeHelper
  def self.weekend?(date)
    date.saturday? || date.sunday?
  end

  def self.datetime(date, halfhour_index)
    hour = (halfhour_index / 2).round
    minute = halfhour_index % 2 == 1 ? 30 : 0
    # rubocop:disable Style/DateTime
    # Time is too slow on Windows, order of magnitude slower than DateTime
    DateTime.new(date.year, date.month, date.day, hour, minute, 0)
    # rubocop:enable Style/DateTime
  end

  def self.date_and_half_hour_index(datetime)
    date = Date.new(datetime.year, datetime.month, datetime.day)
    index = datetime.hour * 2 + (datetime.minute % 30)
    [date, index]
  end
end
