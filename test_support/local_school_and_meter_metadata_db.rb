require 'yaml'
require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# Loads meta data defining schools and a list of meters (no readings)
# from local yml file for test support
# creates schools and meter collections
class AnalysticsSchoolAndMeterMetaData
  include Logging

  def initialize
    @meter_collections = {} # [school_name] => meter_collection
    load_schools_metadata 
  end

  def school(school_name)
    @meter_collections[school_name]
  end

  private

  def meterreadings_cache_directory
    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= File.join(File.dirname(__FILE__), '../MeterReadings/')
    ENV['CACHED_METER_READINGS_DIRECTORY'] 
  end

  def school_metadata_filename
    meterreadings_cache_directory + 'schoolsandmeters.yml'
  end

  # load all metadata for known schools - basically school name, area, pupils, postcode, plus a list of meters etc.
  def load_schools_metadata
    load_schools(school_metadata_filename)
  end

  def load_schools(filename)
    logger.debug "Loading school and meter definitions from #{filename}"
    @schools_metadata = YAML::load_file(filename)

    @schools_metadata.sort.each do |name, school_metadata|
      gas_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :gas }
      electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :electricity }
      logger.debug sprintf("\t\t%-40.40s %10.10s gas x %d electricity x %d\n", name, @schools_metadata[:postcode], gas_meters_metadata.length, electric_meters_metadata.length)
      @meter_collections[name] = create_meter_collection(name, school_metadata, school_metadata[:meters])
    end
  end

  def create_meter_collection(school_name, school_metadata, meter_metadata)
    school = create_school(school_name)
    meter_collection = MeterCollection.new(school)

    gas_meters = create_meters(meter_collection, school_metadata[:meters], :gas)
    gas_meters.each do |gas_meter|
      meter_collection.add_heat_meter(gas_meter)
    end

    electricity_meters = create_meters(meter_collection, school_metadata[:meters], :electricity)
    electricity_meters.each do |electricity_meter|
      meter_collection.add_electricity_meter(electricity_meter)
    end

    meter_collection
  end

  def create_meters(meter_collection, meter_metadata, fuel_type)
    meter_list = []

    meters_of_fuel_type = meter_metadata.select { |v| v[:meter_type] == fuel_type }

    meters_of_fuel_type.each do |meter_data|
      meter_list.push(create_empty_meter(meter_collection, meter_data))
    end

    meter_list
  end

  def create_school(school_name)
    logger.debug "Creating School: #{school_name}"
    school_metadata = @schools_metadata[school_name]

    school = School.new(
      school_name,
      school_metadata[:postcode],
      school_metadata[:floor_area],
      school_metadata[:pupils],
      school_metadata[:school_type]
    )

    school.urn = school_metadata[:urn] if school_metadata.key?(:urn)

    school
  end

  def create_empty_meter(meter_collection, meter_data)
    fuel_type = meter_data[:meter_type]
    identifier_type = fuel_type == :electricity ? :mpan : :mprn
    identifier = meter_data[identifier_type]
    name = meter_data[:name]

    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{name}"

    meter = Meter.new(
      meter_collection,
      AMRData.new(fuel_type),
      fuel_type,
      identifier,
      name,
      meter_data[:floor_area],
      meter_data[:pupils],
      nil, # solar pv
      nil # storage heater
    )

    meter.set_meter_no(meter_data[:meter_no]) if meter_data.key?(:meter_no)
    meter
  end
end

