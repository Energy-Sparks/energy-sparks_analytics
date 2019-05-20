# implements equivalences from electricity, gas kWh to equivlence
# derives data from existing EnergyEquivalences::ENERGY_EQUIVALENCES data
class EnergyConversions
  def initialize(meter_collection)
    @meter_collection = meter_collection
    @conversion_list = EnergyConversions.front_end_conversion_list
  end

  def self.front_end_conversion_list
    conversion_choices = EnergyConversions.generate_conversion_list
    conversion_choices.merge(self.additional_frontend_only_variable_descriptions)
  end

  def front_end_convert(convert_to, time_period, meter_type)
    conversion = @conversion_list[convert_to]
    via_unit      = conversion[:via]
    key           = conversion[:primary_key]
    converted_to  = conversion[:converted_to]

    results = convert(key, via_unit, time_period, meter_type, converted_to)

    results.merge!(scaled_results(conversion, time_period, results)) if conversion.key?(:equivalence_timescale)

    results
  end

  def convert(convert_to, kwh_co2_or_£, time_period, meter_type, units_of_equivalance = nil)
    basic_unit = [:kwh, :co2, :£].include?(convert_to)
    raise EnergySparksUnexpectedStateException.new('Expecting 2nd parameter to be same as first for kwh, co2 or £') if basic_unit && convert_to != kwh_co2_or_£
    conversion = basic_unit ? 1.0 : EnergyEquivalences::ENERGY_EQUIVALENCES[convert_to][:conversions][kwh_co2_or_£][:rate]
    kwh = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, :kwh)
    value = kwh_co2_or_£ == :kwh ? kwh : ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, kwh_co2_or_£)
    equivalence = value / conversion

    {
      equivalence:                equivalence,
      formatted_equivalence:      FormatEnergyUnit.format(units_of_equivalance, equivalence),
      units_of_equivalance:       units_of_equivalance,
      kwh:                        kwh,
      formatted_kwh:              FormatEnergyUnit.format(:kwh, kwh),
      value_in_via_units:         value, # in kWh, CO2 or £
      formatted_via_units_value:  FormatEnergyUnit.format(kwh_co2_or_£, value),
      conversion:                 conversion,
      conversion_factor:          value / kwh,
      via:                        kwh_co2_or_£
    }
  end

  def conversion_choices(kwh_co2_or_£)
    choices = EnergyEquivalences::ENERGY_EQUIVALENCES.select { |_equivalence, conversions| conversions[:conversions].key?(kwh_co2_or_£) }
    choices.keys
  end

  private def scaled_results(conversion, time_period, unscaled_results)
    scale = scale_conversion_period(time_period, conversion[:equivalence_timescale])
    scaled_equivalence = unscaled_results[:equivalence] * scale 
    formatted_equivalence = FormatEnergyUnit.format(conversion[:timescale_units], scaled_equivalence)
    {
      equivalence_scaled_to_time_period:    scaled_equivalence,
      formatted_equivalence_to_time_period: formatted_equivalence
    }
  end

  # scale conversion to time period of equivelance
  # e.g. if a request is made to provide an equivalence of 1 week of school electricity use
  #      but for example the conversion constants are in years, divided the conversion by 52 weeks/year
  private def scale_conversion_period(time_period, equivalence_timescale)
    school_period = time_period.keys[0]
    school_period_days = days_for_period(school_period)
    equivalence_period_days = days_for_period(equivalence_timescale)
    equivalence_period_days / school_period_days
  end

  private def days_for_period(period)
    case period
    when :year, :academicyear
      365.0
    when :month
      (365.0 / 12.0)
    when :week, :schoolweek, :workweek
      7.0
    when :day
      1.0
    when :hour
      (1.0 / 24.0)
    when :working_hours
      (365.0 * 24.0) / (39.0 * 5.0 * 6.0) / 24.0
    else
      period_description = period.nil? ? 'nil' : period.to_s
      raise EnergySparksUnexpectedStateException.new("Unexpected period for equivalence #{period_description}")
    end
  end

  # returns for example :ice_car_co2_km
  private_class_method def self.key_for_equivalence_conversion(type, via, convert_to)
    "#{type}_#{via}_#{convert_to}".to_sym
  end

  # converts energy_equivalence_conversions ENERGY_EQUIVALENCES to form flattened choice of conversions for the from end
  def self.generate_conversion_list
    conversions = {}
    EnergyEquivalences::ENERGY_EQUIVALENCES.each do |conversion_key, conversion_data|
      next unless conversion_data.key?(:convert_to)
      conversion_data[:conversions].each do |via, via_data|
        next unless via_data.key?(:front_end_description)
        front_end_sym = key_for_equivalence_conversion(conversion_key, via, conversion_data[:convert_to])
        conversions[front_end_sym] = create_description(conversion_key, conversion_data, via, via_data)
      end
    end
    conversions
  end

  private_class_method def self.create_description(conversion_key, conversion_data, via, via_data)
    description = {
      description:  via_data[:front_end_description],
      via:          via,
      converted_to: conversion_data[:convert_to],
      primary_key:  conversion_key
    }
    merge_in_additional_information(description, via_data, :calculation_variables)
    merge_in_additional_information(description, conversion_data, :equivalence_timescale)
    merge_in_additional_information(description, conversion_data, :timescale_units)
    description
  end

  # should be private, but had to make public because Ruby doesn't handle this well
  def self.additional_frontend_only_variable_descriptions
    {
      kwh: {
        description:    'meter data in kWh',
        via:            :kwh,
        converted_to:   :kwh,
        primary_key:    :kwh
      },
      co2: {
        description:    'meter data in co2',
        via:            :co2,
        converted_to:   :co2,
        primary_key:    :co2
      },
      £: {
        description:    'meter data in £',
        via:            :£,
        converted_to:   :£,
        primary_key:    :£
      }
    }
  end

  private_class_method def self.merge_in_additional_information(conversions, from_hash, from_key)
    conversions.merge!(from_key => from_hash[from_key]) if from_hash.key?(from_key)
  end
end
