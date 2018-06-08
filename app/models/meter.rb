# meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
class Meter
  attr_reader :building, :amr_data, :fuel_type, :floor_area, :pupils
  # Energy Sparks activerecord fields:
  attr_reader :active, :created_at, :id, :meter_no, :meter_type, :name, :school, :updated_at
  # enum meter_type: [:electricity, :gas]

  def initialize(building, amr_data, type, identifier, name, floor_area = nil, pupils = nil)
    @amr_data = amr_data
    @building = building
    @meter_type = type # think Energy Sparks variable naming is a minomer (PH,31May2018)
    @fuel_type = type
    @id = identifier
    @name = name
    @floor_area = floor_area
    @number_of_pupils = pupils
    puts "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{pupils}"
  end

  # Matches ES AR version
  def display_name
    name.present? ? "#{meter_no} (#{name})" : display_meter_number
  end

  def display_meter_number
    meter_no.present? ? meter_no : meter_type.to_s
  end
end
