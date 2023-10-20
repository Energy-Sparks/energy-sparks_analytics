# frozen_string_literal: true

require_relative '../../lib/dashboard/utilities/restricted_key_hash'
# helper class for main solar aggregation service
# keeps track of the 5 to 7 meters being manipulated
class PVMap < RestrictedKeyHash
  MPAN_KEY_MAPPINGS = {
    export_mpan: :export,
    production_mpan: :generation,
    production_mpan2: :generation2,
    production_mpan3: :generation3
  }.freeze

  def self.unique_keys
    %i[
      export
      generation
      generation2
      generation3
      self_consume
      mains_consume
      mains_plus_self_consume
      generation_meter_list
    ]
  end

  def self.generation_meters
    %i[
      generation
      generation2
      generation3
    ]
  end

  def self.optional_keys
    %i[
      generation2
      generation3
      generation_meter_list
    ]
  end

  def self.mpan_maps(mpan_map)
    mpan_map.select { |k, _v| MPAN_KEY_MAPPINGS.keys.include?(k)}
  end

  def self.attribute_map_meter_type(mpan_meter_type)
    MPAN_KEY_MAPPINGS[mpan_meter_type]
  end

  def self.meter_type_attribute_map(meter_type)
    MPAN_KEY_MAPPINGS.key(meter_type)
  end

  def self.meter_type_to_name_map
    {
      export: SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
      generation: SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      self_consume: SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
      mains_consume: SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
      mains_plus_self_consume: SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
    }
  end

  def all_required_key_values_non_nil?
    each do |k, v|
      return false if v.nil? && !self.class.optional_keys.include?(k)
    end
    true
  end

  def number_of_generation_meters
    count { |k, v| self.class.generation_meters.include?(k) && !v.nil? }
  end

  def set_nil_value(list_of_keys)
    list_of_keys.each do |k|
      self[k] = nil
    end
  end
end
