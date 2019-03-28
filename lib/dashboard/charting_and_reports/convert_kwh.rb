class ConvertKwh
  # convert from kwh to a different unit
  # - fuel_type: :gas, :electricity is required for £ & CO2 conversion
  def self.scale_unit_from_kwh(unit, fuel_type)
    unit_scale = nil
    case unit
    when :kwh
      unit_scale = 1.0
    when :kw
      unit_scale = 2.0 # kWh in 30 mins, but perhap better to raise error
    when :co2 # https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2018
      case fuel_type
      when :electricity, :storage_heater
        unit_scale = 0.283 # 283g/kWh UK Grid Intensity
      when :gas, :heat # TODO(PH,1Jun2018) - rationalise heat versus gas
        unit_scale = 0.204 # 204g/kWh
      when :oil
        unit_scale = 0.285 # 285g/kWh
      when :solar_pv
        unit_scale = 0.040 # 40g/kWh - life cycle costs TODO(PH,14Jun2018) find reference to current UK official figures
      else
        raise "Error: CO2: unknown fuel type #{fuel_type}" unless fuel_type.nil?
        raise 'Error: CO2: nil fuel type'
      end
    when :£
      case fuel_type
      when :electricity, :storage_heater, :aggregated_electricity
        unit_scale = BenchmarkMetrics::ELECTRICITY_PRICE # 12p/kWh long term average
      when :solar_export
        unit_scale = BenchmarkMetrics::SOLAR_EXPORT_PRICE # 5p/kWh
      when :gas, :heat # TODO(PH,1Jun2018) - rationalise heat versus gas
        unit_scale = BenchmarkMetrics::GAS_PRICE # 3p/kWh long term average
      when :oil
        unit_scale = BenchmarkMetrics::OIL_PRICE # 5p/kWh long term average
      when :solar_pv
        unit_scale = -1 * scale_unit_from_kwh(:£, :electricity)
      else
        raise EnergySparksUnexpectedStateException.new("Error: £: unknown fuel type #{fuel_type}") unless fuel_type.nil?
        raise EnergySparksUnexpectedStateException.new('Error: £: nil fuel type')
      end
    when :library_books
      unit_scale = scale_unit_from_kwh(:£, fuel_type) / 5.0 # £5 per library book
    else
      raise "Error: unknown unit type #{unit}" unless unit.nil?
      raise 'Error: nil unit type'
    end
    unit_scale
  end
  
  def self.convert(from_unit, to_unit, fuel_type, from_value)
    from_scaling = ConvertKwh.scale_unit_from_kwh(from_unit, fuel_type)
    to_scaling = ConvertKwh.scale_unit_from_kwh(to_unit, fuel_type)
    from_value * to_scaling / from_scaling
  end
end