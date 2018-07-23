# time of day (differentiates between 00:00 and 24:00)
class TimeOfDay
  include Comparable

  attr_reader :hour, :minutes, :relative_time

  def initialize(hour, minutes)
    if hour.nil? || minutes.nil? || hour < 0 || hour > 24 || minutes < 0 || minutes >= 60 || (hour == 24 && minutes != 0)
      raise EnergySparksUnexpectedStateException.new("Unexpected time of day setting #{hour}:#{minutes}")
    end
    @hour = hour
    @minutes = minutes
    @relative_time = Time.new(1970, 1, 1, hour, minutes, 0)
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

  def strftime(options)
    relative_time.strftime(options)
  end

  def <=>(other)
    other.class == self.class && [hour, minutes] <=> [other.hour, other.minutes]
  end

  def - (value)
    relative_time - value.relative_time
  end
end