require 'logger'
require './halfhourlydata'

class SolarIrradiance < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def get_solar_irradiance(date, half_hour_index)
    getData(date, half_hour_index)
  end
end

class SolarIrradianceLoader < HalfHourlyLoader
  def initialize(csv_file, irradiance)
    super(csv_file, 0, 1, 0, irradiance)
  end
end
