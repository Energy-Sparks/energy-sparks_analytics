class Temperatures < HalfHourlyData
  include Logging

  FROSTPROTECTIONTEMPERATURE = 4.0
  def initialize(type)
    super(type)
    @cached_min_max = {}
  end

  def get_temperature(date, half_hour_index)
    logger.error 'Warning: deprecated interface get_temperature'
    logger.error Thread.current.backtrace.join("\n")
    temperature(date, half_hour_index)
  end

  def temperature(date, half_hour_index)
    data(date, half_hour_index)
  end

  def average_temperature(date)
    avg_temp = 0.0
    (0..47).each do |i|
      if data(date, i).nil?
        logger.debug "No data for #{date} index #{i}"
      else
        avg_temp += data(date, i) / 48
      end
    end
    avg_temp
  end

  def temperature_range(start_date, end_date)
    return @cached_min_max[start_date..end_date] if @cached_min_max.key?(start_date..end_date)
    min_temp = 100.0
    max_temp = -100.0
    (start_date..end_date).each do |date|
      (0..47).each do |i|
        temp = temperature(date, i)
        min_temp = temp < min_temp ? temp : min_temp
        max_temp = temp > max_temp ? temp : max_temp
      end
    end
    @cached_min_max[start_date..end_date] = [min_temp, max_temp]
    [min_temp, max_temp]
  end

  def halfhours_below_temperature(start_date, end_date, temperature_level, day_of_week = nil, holidays = nil, is_holiday = nil)
    halfhour_count = 0
    (start_date..end_date).each do |date|
      next if !is_holiday.nil? && !holidays.nil? && holidays.holiday?(date) == is_holiday
      next if !day_of_week.nil? && day_of_week != date.wday
      (0..47).each do |i|
        halfhour_count += 1 if temperature(date, i) <= temperature_level
      end
    end
    halfhour_count
  end

  # find days with longest number of half hours below 4C, deal with duplicate stats
  def frost_days(start_date, end_date, day_of_week = nil,  holidays = nil, is_holiday = nil)
    frostdates_by_num_halfhours = Array.new(49){Array.new} # zero half hours, plus 48, up to all day = 48, so 49 buckets
    end_date.downto(start_date) do |date| # reverse order so recent more prominent
      halfhours = halfhours_below_temperature(date, date, FROSTPROTECTIONTEMPERATURE, day_of_week, holidays, is_holiday)
      frostdates_by_num_halfhours[halfhours].push(date) if halfhours > 0
    end

    frost_dates = []
    48.downto(0) do |halfhours|
      frostdates_by_num_halfhours[halfhours].each do |date|
        frost_dates.push(date)
      end
    end
    frost_dates
  end

  # find days with highest idurnal ranges, for thermostatic analysis
  def largest_diurnal_ranges(start_date, end_date, winter = false,  weekend = nil, holidays = nil, is_holiday = nil)
    # get a list of diurnal ranges
    diurnal_ranges = {} # diurnal temperature date = [list of dates with that range] i.e. deal with duplicates
    end_date.downto(start_date) do |date| # reverse order so recent more prominent
      next if !weekend.nil? && weekend != DateTimeHelper.weekend?(date)
      next if winter && ![11, 12, 1, 2, 3].include?(date.month)
      next if !is_holiday.nil? && !holidays.nil? && holidays.holiday?(date) != is_holiday
      min_temp, max_temp = temperature_range(date, date)
      diurnal_range = max_temp - min_temp
      diurnal_ranges[diurnal_range] = Array.new unless diurnal_ranges.key?(diurnal_range)
      diurnal_ranges[diurnal_range].push(date)
    end

    # flatten list and return dates in order of biggest diurnal ranges
    descending_diurnal_ranges_dates = []
    descending_diurnal_ranges = diurnal_ranges.keys.sort.reverse
    descending_diurnal_ranges.each do |diurnal_range|
      descending_diurnal_ranges_dates.concat(diurnal_ranges[diurnal_range])
    end
    descending_diurnal_ranges_dates
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
    (0..47).each do |halfhour_index|
      dh += degree_hour(date, halfhour_index, base_temp)
    end
    dh / 48
  end

  def degree_hour(date, halfhour_index, base_temp)
    dh = 0.0
    t = data(date, halfhour_index)
    dh = base_temp - t if t <= base_temp
    dh
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
        logger.debug "mod deg days #{date} : #{before} becomes #{after}"
      end
      return (base_temp - avg_temperature) + 0.0 * frost_degree_hours / 8.0
    else
      return 0.0
    end
  end

  # used for simulator air con calculations
  def cooling_degree_days_at_time(date, half_hour_index, base_temp)
    temp = temperature(date, half_hour_index)
    # Patch for when temp comes back as nil
    return 0.0 if temp.nil?

    if temp >= base_temp
      temp - base_temp
    else
      0.0
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
