class GridCarbonIntensity < HalfHourlyData
  def initialize
    super('UK Grid Carbon Intensity')
  end

  def grid_carbon_intensity(date, half_hour_index)
    data(date, half_hour_index)
  end
end

class GridCarbonLoader < HalfHourlyLoader
  def initialize(csv_file, carbon)
    super(csv_file, 0, 1, 0, carbon)
  end
end
