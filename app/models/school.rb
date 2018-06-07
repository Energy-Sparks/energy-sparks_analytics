# school: defines a school
#         currently derives from Building
#           - TODO(PH,JJ,3Jun18) - at some point decide whether
#           - this is the correct model
require './app/models/building'
require './app/models/meter'
require_relative '../../lib/validateamrdata'

class School < Building
  # Energy Sparks activerecord fields:
  attr_reader :address, :calendar_id, :competition_role, :created_at, :electricity_dataset, :enrolled
  attr_reader :gas_dataset, :id, :level, :name, :postcode, :sash_id, :school_type, :slug, :update_at
  attr_reader :urn, :website

  def initialize(name, address = nil, floor_area = nil, pupils = nil, type = nil)
    super(name, address, floor_area, pupils)
    @school_type = type
  end

  def validate_and_aggregate_meter_data
    validate_meter_data
    aggregate_heat_meters
    aggregate_electricity_meters
  end

private

  def validate_meter_data
    validate_meter_list(@heat_meters)
    validate_meter_list(@electricity_meters)
  end

  def validate_meter_list(list_of_meters)
    puts "Validating #{list_of_meters.length} meters"
    list_of_meters.each do |meter|
      validate_meter = ValidateAMRData.new(meter, 30, holidays, temperatures)
      validate_meter.validate
    end
  end
end
