class EnergyConversions
  def initialize(meter_collection)
    @meter_collection = meter_collection
  end

  CONVERSIONSFORFRONTEND = {
    ice_car_kwh_km:  {
      description:          'Distance (km) travelled by a petrol car (conversion using kwh)',
      calculation:          'A petrol car...............',
      via:                  :kwh,
      converted_to:         :km,
      key:                  :ice_car
    },
    ice_car_co2_km:  {
      description:          'Distance (km) travelled by a petrol car(conversion using co2)',
      calculation:          'A petrol car...............',
      via:                  :co2,
      converted_to:         :km,
      key:                  :ice_car
    }
  }.freeze

  def equivalences_available_to_front_end
    CONVERSIONSFORFRONTEND
  end

  def front_end_convert(convert_to, time_period, meter_type)
    via_unit = CONVERSIONSFORFRONTEND[convert_to][:via]
    key = CONVERSIONSFORFRONTEND[convert_to][:key]
    converted_to = CONVERSIONSFORFRONTEND[convert_to][:converted_to]
    convert(key, via_unit, time_period, meter_type, converted_to)
  end

  def convert(convert_to, kwh_co2_or_£, time_period, meter_type, units_of_equivalance = nil)
    kwh = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, :kwh)
    value = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, kwh_co2_or_£)
    conversion = EnergyEquivalences::ENERGY_EQUIVALENCES[convert_to][:conversions][kwh_co2_or_£][:rate]
    equivalence = value / conversion
    {
      equivalence:                equivalence,
      formatted_equivalence:      FormatEnergyUnit.format(units_of_equivalance, equivalence),
      units_of_equivalance:       units_of_equivalance,
      kwh:                        kwh,
      formatted_kwh:              FormatEnergyUnit.format(:kwh, kwh),
      value_in_via_units:         value, # in kWh, CO2 or £
      formatted_via_units_value:  FormatEnergyUnit.format(kwh_co2_or_£, value),
      units_of_equivalence:       kwh_co2_or_£,
      conversion:                 conversion,
      conversion_factor:          value / kwh,
      via:                        kwh_co2_or_£
    }
  end

  def conversion_choices(kwh_co2_or_£)
    choices = EnergyEquivalences::ENERGY_EQUIVALENCES.select { |_equivalence, conversions| conversions[:conversions].key?(kwh_co2_or_£) }
    choices.keys
  end
end
