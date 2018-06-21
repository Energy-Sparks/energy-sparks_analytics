# meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
class MeterAnalysis
  # Extra fields - potentially a concern or mix-in
  attr_reader :building, :fuel_type, :floor_area, :number_of_pupils
  attr_reader :solar_pv_installation, :storage_heater_config, :sub_meters
  attr_accessor :amr_data

  # Energy Sparks activerecord fields:
  attr_reader :active, :created_at, :meter_no, :meter_type, :school, :updated_at
  attr_accessor :id, :name
  # enum meter_type: [:electricity, :gas]

  def initialize(building, amr_data, type, identifier, name,
                  floor_area = nil, number_of_pupils = nil,
                  solar_pv_installation = nil, storage_heater_config = nil)
    @amr_data = amr_data
    @building = building
    @meter_type = type.to_sym # think Energy Sparks variable naming is a minomer (PH,31May2018)
    @fuel_type = type
    @id = identifier
    @name = name
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    @solar_pv_installation = solar_pv_installation
    @storage_heater_config = storage_heater_config
    @sub_meters = []
    puts "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{number_of_pupils}"
  end

  # Matches ES AR version
  def display_name
    name.present? ? "#{meter_no} (#{name})" : display_meter_number
  end

  def display_meter_number
    meter_no.present? ? meter_no : meter_type.to_s
  end
end
