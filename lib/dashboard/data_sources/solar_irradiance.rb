class SolarIrradiance < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def solar_irradiance(date, half_hour_index)
    data(date, half_hour_index)
  end
end

class SolarIrradianceLoader < HalfHourlyLoader
  def initialize(csv_file, irradiance)
    super(csv_file, 0, 1, 0, irradiance)
  end
end
