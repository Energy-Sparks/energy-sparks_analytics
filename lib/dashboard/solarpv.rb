class SolarPV < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def get_solar_pv_yield(date, half_hour_index)
    getData(date, half_hour_index)
  end
end

class SolarPVLoader < HalfHourlyLoader
  def initialize(csv_file, pv)
    super(csv_file, 0, 1, 0, pv)
  end
end
