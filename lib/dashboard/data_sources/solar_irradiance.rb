class SolarIrradiance < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def solar_irradiance(date, half_hour_index)
    data(date, half_hour_index)
  end

  def average_days_irradiance_above_threshold(date, threshold)
    total = 0.0
    count = 0
    (0..48).each do |halfhour_index|
      irr = irradiance(date, halfhour_index)
      if irr > threshold
        total += irr
        count += 1
      end
    end
    total / count
  end

  def average_days_irradiance_between_times(date, halfhour_index1, halfhour_index2)
    total = 0.0
    (halfhour_index1..halfhour_index2).each do |halfhour_index|
      total += irradiance(date, halfhour_index)
      irr = irradiance(date, halfhour_index)
    end
    total / (halfhour_index2 - halfhour_index1 + 1)
  end

  def irradiance(date, half_hour_index)
    data(date, half_hour_index)
  end
end

class SolarIrradianceLoader < HalfHourlyLoader
  def initialize(csv_file, irradiance)
    super(csv_file, 0, 1, 0, irradiance)
  end
end
