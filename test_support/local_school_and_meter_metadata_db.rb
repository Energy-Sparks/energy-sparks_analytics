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

  def school(identifier, identifier_type = :name)
    find_school(identifier, identifier_type)
  end

  private

  def find_school(identifier, identifier_type)
    @meter_collections.each_value do |meter_collection|
      return meter_collection if meter_collection.matches_identifier?(identifier, identifier_type)
    end
    nil
  end

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
      aggregate_electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_heat }
      aggregate_heat_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_electricity }
      aggregate_electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_heat }
      logger.debug sprintf("\t\t%-40.40s %10.10s gas x %d electricity x %d aggregated heat x %d aggregated electric %d\n",
                    name, @schools_metadata[:postcode], gas_meters_metadata.length, electric_meters_metadata.length,
                    aggregate_heat_meters_metadata.length, aggregate_electric_meters_metadata.length)
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

    aggregated_heat_meters = create_meters(meter_collection, school_metadata[:meters], :aggregated_heat)
    if !aggregated_heat_meters.nil? && aggregated_heat_meters.length > 1
      logger.error 'More than one aggregate heat meter encountered loading metadata'
    end
    aggregated_heat_meters.each do |aggregate_heat_meter|
      meter_collection.add_aggregate_heat_meter(aggregate_heat_meter)
    end

    aggregated_electricity_meters = create_meters(meter_collection, school_metadata[:meters], :aggregated_electricity)
    if !aggregated_electricity_meters.nil? && aggregated_electricity_meters.length > 1
      logger.error 'More than one aggregate electricityeat meter encountered loading metadata'
    end
    aggregated_electricity_meters.each do |aggregated_electricity_meter|
      meter_collection.add_aggregate_electricity_meter(aggregated_electricity_meter)
    end

    create_missing_aggregate_meters(meter_collection, school_metadata)

    logger.info "Created meter collection #{meter_collection.to_s}"
    meter_collection
  end

  def create_meters(meter_collection, meter_metadata, fuel_type)
    meter_list = []

    meters_of_fuel_type = meter_metadata.select { |v| v[:meter_type] == fuel_type }

    meters_of_fuel_type.each do |meter_data|
      meter_list.push(create_empty_meter_from_meta_data(meter_collection, meter_data))
    end

    meter_list
  end

  # sometimes aggregate meters are already defined (in metadata)
  # sometimes if there is only one meter of a fuel type,
  #  the aggregate meter is a reference to the underlying single fule type meter
  # sometimes one needs to be created on the fly, with a mpan/mprn of the URN + 8000** or 90****
  def create_missing_aggregate_meters(meter_collection, meter_data)
    if meter_collection.aggregated_electricity_meters.nil?
      if !meter_collection.electricity_meters.nil? && meter_collection.electricity_meters.length > 1
        # for the moment only create a combined meter if multiple underlying meters of same type
        meter_collection.aggregated_electricity_meters = create_empty_combined_meter(meter_collection, 'Combined Electricity Meter', :aggregated_electricity, meter_data)
      end
    end
    if meter_collection.aggregated_heat_meters.nil?
      if !meter_collection.heat_meters.nil? && meter_collection.heat_meters.length > 1
        # for the moment only create a combined meter if multiple underlying meters of same type
        meter_collection.aggregated_heat_meters = create_empty_combined_meter(meter_collection, 'Combined Heat Meter', :aggregated_heat, meter_data)
      end
    end
  end

  def create_empty_combined_meter(meter_collection, name, fuel_type, meter_data)
    create_empty_meter(
      meter_collection,
      name,
      MeterAnalysis.synthetic_combined_meter_mpan_mprn_from_urn(meter_data[:urn], fuel_type),
      fuel_type,
      meter_data[:floor_area],
      meter_data[:pupils],
      meter_data.key?(:meter_no) ? meter_data[:meter_no] : nil
    )
  end

  def create_school(school_name)
    school_metadata = @schools_metadata[school_name]

    logger.debug "Creating School: #{school_name} #{school_metadata[:postcode]}"

    school = SchoolAnalysis.new(
      school_name,
      school_metadata[:postcode],
      school_metadata[:floor_area],
      school_metadata[:pupils],
      school_metadata[:school_type],
      school_metadata[:area],
      school_metadata[:urn],
      school_metadata[:postcode]
    )

    school
  end

  def create_empty_meter_from_meta_data(meter_collection, meter_data)
    fuel_type = meter_data[:meter_type]
    identifier_type = (fuel_type == :electricity || fuel_type == :aggregated_electricity) ? :mpan : :mprn

    create_empty_meter(
      meter_collection,
      meter_data[:name],
      meter_data[identifier_type],
      fuel_type,
      meter_data[:floor_area],
      meter_data[:pupils],
      meter_data.key?(:meter_no) ? meter_data[:meter_no] : nil
    )
  end

  def create_empty_meter(meter_collection, name, identifier, fuel_type, floor_area, pupils, meter_no)

    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{name}"

    meter = MeterAnalysis.new(
      meter_collection,
      AMRData.new(fuel_type),
      fuel_type,
      identifier,
      name,
      floor_area,
      pupils,
      nil, # solar pv
      nil # storage heater
    )

    meter.set_meter_no(meter_no) unless meter_no.nil?
    meter
  end
end
