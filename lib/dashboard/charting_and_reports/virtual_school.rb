# Helper class for creating an artificial school e.g. average or exemplar
class VirtualSchool
  include Logging

  attr_reader :school, :name, :urn, :floor_area, :number_of_pupils, :school_type, :area_name

  def initialize(name, urn, floor_area, number_of_pupils, school_type = :primary, area_name = 'Bath')
    @name = name
    @urn = urn
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    @school_type = school_type
    @area_name = area_name
  end

  def create_school
    @school = create_meter_collection
  end

  private

  def create_meter_collection
    logger.debug "Creating School: #{name}"

    na = 'Not Applicable'

    school = Dashboard::School.new(name, na, floor_area, number_of_pupils, :primary, area_name, urn, na)

    meter_collection = MeterCollection.new(school)

    meter_collection.add_electricity_meter(
      create_empty_meter(meter_collection, name + ' Electricity', :electricity)
    )

    meter_collection.add_heat_meter(
      create_empty_meter(meter_collection, name + ' Gas', :gas)
    )

    meter_collection
  end

  def create_empty_meter(meter_collection, meter_name, fuel_type)
    identifier = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(urn, fuel_type)

    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{meter_name}"

    meter = Dashboard::Meter.new(
      meter_collection,
      AMRData.new(fuel_type),
      fuel_type,
      identifier,
      meter_name,
      floor_area,
      number_of_pupils,
      nil, # solar pv
      nil, # storage heater
      nil  # Meter attributes hash for this meter
    )
  end

end