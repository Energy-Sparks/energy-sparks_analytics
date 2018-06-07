require 'logger'
require './halfhourlydata'

class Temperatures < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def get_temperature(date, half_hour_index)
    data(date, half_hour_index)
  end

  def average_temperature(date)
    avg_temp = 0.0
    (0..47).each do |i|
      avg_temp += data(date, i) / 48
    end
    avg_temp
  end

  def temperature_range(start_date, end_date)
    min_temp = 100.0
    max_temp = -100.0
    (start_date..end_date).each do |date|
      (0..47).each do |i|
        temp = temperature(date, i)
        min_temp = temp < min_temp ? temp : min_temp
        max_temp = temp > max_temp ? temp : max_temp
      end
    end
    [min_temp, max_temp]
  end

  def temperature_datetime(datetime)
    date, half_hour_index = DateTimeHelper.date_and_half_hour_index(datetime)
    temperature(date, half_hour_index)
  end

  def degreesday_range(start_date, end_date, base_temp)
    min_temp, max_temp = temperature_range(start_date, end_date)
    degreeday_min = max_temp > base_temp ? 0.0 : (max_temp - base_temp)
    degreeday_max = min_temp > base_temp ? 0.0 : (min_temp - base_temp)
    [degreeday_min, degreeday_max]
  end

  def degree_hours(date, base_temp)
    dh = 0.0
    (0..47).each do |i|
      t = data(date, i)
      if t <= base_temp
        dh = dh + base_temp - t
      end
    end
    dh / 48
  end

  def degree_days(date, base_temp)
    # return modified_degree_days(date, base_temp)
    avg_temperature = average_temperature(date)

    if avg_temperature <= base_temp
      return base_temp - avg_temperature
    else
      return 0.0
    end
  end

  def average_temperature_in_date_range(start_date, end_date)
    if start_date < self.start_date || end_date > self.end_date
      return nil # NAN blows up write_xlsx
    end
    total_temperature = 0.0
    (start_date..end_date).each do |date|
      total_temperature += average_temperature(date)
    end
    total_temperature / (end_date - start_date + 1)
  end

  def average_degree_days_in_date_range(start_date, end_date, base_temp)
    if start_date < self.start_date || end_date > self.end_date
      return nil # NAN blows up write_xlsx
    end
    total_degree_days = 0.0
    (start_date..end_date).each do |date|
      avg_temperature = average_temperature(date)

      if avg_temperature <= base_temp
        total_degree_days += base_temp - avg_temperature
      end
    end
    total_degree_days / (end_date - start_date + 1)
  end

  def modified_degree_days(date, base_temp)
    frost_degree_hours = 0.0
    (0..47).each do |i|
      if i < 2 * 6 || i > 2 * 19
        frost_degree_hours += (20 - temp) / 2.0 if temperature(date, i) < 4
      end
    end

    avg_temperature = average_temperature(date)
    if avg_temperature <= base_temp
      if frost_degree_hours > 0
        before = (base_temp - avg_temperature)
        after = (base_temp - avg_temperature) + frost_degree_hours / 8.0
        puts "mod deg days #{date} : #{before} becomes #{after}"
      end
      return (base_temp - avg_temperature) + 0.0 * frost_degree_hours / 8.0
    else
      return 0.0
    end
  end

  # used for simulator air con calculations
  def cooling_degree_days_at_time(date, base_temp, half_hour_index)
    temperature = getTemperature(date, half_hour_index)

    if temperature >= base_temp
      return temperature - base_temp
    else
      return 0.0
    end
  end

  # end_date inclusive
  def degrees_days_average_in_range(base_temp, start_date, end_date)
    d_days = 0.0
    (start_date..end_date).each do |date|
      d_days += degree_days(date, base_temp)
    end
    d_days / (end_date - start_date + 1)
  end
end

class TemperaturesLoader < HalfHourlyLoader
  def initialize(csv_file, temperatures)
    super(csv_file, 0, 1, 0, temperatures)
  end
end
