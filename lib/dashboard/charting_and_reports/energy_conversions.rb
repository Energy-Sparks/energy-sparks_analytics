class EnergyConversions
  def initialize(meter_collection)
    @meter_collection = meter_collection
  end

  def convert(convert_to, kwh_co2_or_£, time_period, meter_type)
    kwh = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, :kwh)
    value = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value(time_period, meter_type, kwh_co2_or_£)
    conversion = EnergyEquivalences::ENERGY_EQUIVALENCES[convert_to][:conversions][kwh_co2_or_£][:rate]
    return [value / conversion, value, conversion]
  end

  def conversion_choices(kwh_co2_or_£)
    choices = EnergyEquivalences::ENERGY_EQUIVALENCES.select { |_equivalence, conversions| conversions[:conversions].key?(kwh_co2_or_£) }
    choices.keys
  end
end
