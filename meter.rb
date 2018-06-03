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
    @pupils = pupils
    puts "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{pupils}"
  end

  def display_name
    if name.present?
      name
    else
      meter_no.present? ? meter_no : meter_type.to_s # note additional case compared with Energy Sparks code
    end
  end
end
