# meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
class MeterAnalysis
  include Logging

  # Extra fields - potentially a concern or mix-in
  attr_reader :building, :fuel_type
  attr_reader :solar_pv_installation, :storage_heater_config, :sub_meters, :meter_correction_rules
  attr_accessor :amr_data,  :floor_area, :number_of_pupils

  # Energy Sparks activerecord fields:
  attr_reader :active, :created_at, :meter_no, :meter_type, :school, :updated_at, :mpan_mprn
  attr_accessor :id, :name
  # enum meter_type: [:electricity, :gas]

  def initialize(building, amr_data, type, identifier, name,
                  floor_area = nil, number_of_pupils = nil,
                  solar_pv_installation = nil,
                  storage_heater_config = nil)
    @amr_data = amr_data
    @building = building
    @meter_type = type.to_sym # think Energy Sparks variable naming is a minomer (PH,31May2018)
    @fuel_type = type
    @id = identifier
    @mpan_mprn = identifier.to_i
    @name = name
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    @solar_pv_installation = solar_pv_installation
    @storage_heater_config = storage_heater_config
    @meter_correction_rules = []
    @sub_meters = []
    @active = true
    logger.debug "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{number_of_pupils}"
  end

  def to_s
    @mpan_mprn.to_s + ':' + @fuel_type.to_s + 'x' + (@amr_data.nil? ? '0' : @amr_data.length.to_s)
  end

  def set_meter_no(meter_no)
    @meter_no = meter_no
  end

  def add_correction_rule(rule)
    throw EnergySparksUnexpectedStateException.new('Unexpected nil correction') if rule.nil?
    @meter_correction_rules.push(rule)
  end

  def insert_correction_rules_first(rules)
    @meter_correction_rules = rules + @meter_correction_rules
  end

  # Matches ES AR version
  def display_name
    name.present? ? "#{meter_no} (#{name})" : display_meter_number
  end

  def display_meter_number
    meter_no.present? ? meter_no : meter_type.to_s
  end

  def self.synthetic_combined_meter_mpan_mprn_from_urn(urn, fuel_type)
    if fuel_type == :electricity || fuel_type == :aggregated_electricity
      (90000000000000 + urn.to_i).to_s
    elsif fuel_type == :gas || fuel_type == :aggregated_heat
      (80000000000000 + urn.to_i).to_s
    else
      throw EnergySparksUnexpectedStateException.new('Unexpected fuel_type')
    end
  end
end
