# handles the scaling of the y-axis
# Units:      kWh, kW, CO2, £, Library Books
# Scaling:    none, per pupil, per floor area,
#             per 200 pupils (primary representation), per 1000 pupils (secondary)
#
# ultimately it might have to support some degree day normalisation
# TODO (PH,5Jun2018) this class doesn't really know whether its a global class or an instance at the moment

class YAxisScaling
  include Logging
  attr_reader :units, :scaling_factors
  def initialize
    # rubocop:disable Style/ClassVars, Metrics/LineLength, Lint/UnneededDisable
    @@units = %i[kwh kw co2 £ library_books]
    @@scaling_factors = %i[none per_pupil per_floor_area per_200_pupils per_1000_pupils]
    # rubocop:enable Style/ClassVars, Metrics/LineLength, Lint/UnneededDisable
  end

  def scale_from_kwh(value, unit, scaling_factor_type, fuel_type, meter_collection)
    unit_scale = scale_unit_from_kwh(unit, fuel_type)
    factor = scaling_factor(scaling_factor_type, meter_collection)
    value * factor * unit_scale
  end

  def self.unit_description(unit, scaling_factor_type, value)
    val_str = value.nil? ? 'NA' : value
    puts "Y axis scaling for unit =#{unit} type = #{scaling_factor_type} value = #{val_str}"
    factor_type_description = {
      none:             nil,
      per_pupil:        'per pupil',
      per_floor_area:   'per floor area (m2)',
      per_200_pupils:   'per 200 pupil (average size primary school)',
      per_1000_pupils:  'per 1000 pupil (average size secondary school)'
    }
    unit_description = {
      kwh:            'kWh',
      kw:             'kW',
      co2:            'CO2 (kg)',
      £:              '£',
      library_books:  'library books'
    }
    if scaling_factor_type.nil? || scaling_factor_type == :none
      if unit == :£
        if value.nil?
          '£'
        else
          '£' + scale_num(value)
        end
      else
        # rubocop:disable Style/IfInsideElse
        if value.nil?
          unit_description[unit]
        else
          scale_num(value) + ' ' + unit_description[unit]
        end
        # rubocop:enable Style/IfInsideElse
      end
    else
      # rubocop:disable Style/IfInsideElse
      if unit == :£
        unit_description[unit] + scale_num(value) + '/' + factor_type_description[scaling_factor_type]
      else
        description = unit_description[unit] + '/' + factor_type_description[scaling_factor_type]
        scale_num(value) + ' ' + description
      end
      # rubocop:enable Style/IfInsideElse
    end
  end

  def self.scale_num(number)
    if number.nil?
      '' # specific case where no value specified
    elsif number < 50
      number.round(2).to_s
    elsif number < 1000
      number.round(0).to_s
    else
      number.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end

  def scaling_factor(scaling_factor_type, meter_collection)
    factor = nil
    case scaling_factor_type
    when :none
      factor = 1.0
    when :per_pupil
      factor = 1.0 / meter_collection.number_of_pupils
    when :per_floor_area
      factor = 1.0 / meter_collection.floor_area
    when :per_200_pupils
      factor = scaling_factor(:per_pupil, meter_collection) * 200.0
    when :per_1000_pupils
      factor = scaling_factor(:per_pupil, meter_collection) * 1000.0
    else
      raise "Error: unknown scaling factor #{scaling_factor_type}" unless scaling_factor_type.nil?
      raise 'Error: nil scaling factor'
    end
    factor
  end

  # the whole of this class should really be self
  # TODO(PH,19Jun2018) convert remainder of class to self
  def self.convert(from_unit, to_unit, fuel_type, from_value, round = true)
    y_axis_scaling = YAxisScaling.new
    from_scaling = y_axis_scaling.scale_unit_from_kwh(from_unit, fuel_type)
    to_scaling = y_axis_scaling.scale_unit_from_kwh(to_unit, fuel_type)
    val = from_value * to_scaling / from_scaling
    round ? scale_num(val) : val
  end

  def self.convert_multiple(from_unit, to_units, fuel_type, from_value, round = true)
    converted_values = []
    to_units.each do |to_unit|
      converted_values.push(convert(from_unit, to_unit, fuel_type, from_value))
    end
    converted_values
  end

  # convert from kwh to a different unit
  # - fuel_type: :gas, :electricity is required for £ & CO2 conversion
  def scale_unit_from_kwh(unit, fuel_type)
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
      when :electricity, :storage_heater
        unit_scale = BenchmarkMetrics::ELECTRICITY_PRICE # 12p/kWh long term average
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
end
