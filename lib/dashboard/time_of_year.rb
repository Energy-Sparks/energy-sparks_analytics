# time of year - so only month and day of month
class TimeOfYear
  include Comparable

  attr_reader :month, :day_of_month, :relative_time

  def initialize(month, day_of_month)
    @relative_time = Time.new(1970, month, day_of_month, 0, 0, 0)
    @month = month
    @day_of_month = day_of_month
  end

  def day
    relative_time.day
  end

  def to_s
    @relative_time.strftime('%d %b')
  end

  def <=>(other)
    other.class == self.class && [month, day] <=> [other.month, other.day]
  end
end
