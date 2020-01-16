require 'yaml'
require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# Loads meta data defining schools and a list of meters (no readings)
# from local yml file for test support
# creates schools and meter collections
class AnalysticsSchoolAndMeterMetaData
  include Logging

  attr_reader :meter_collections

  def initialize
    @meter_collections = {} # [school_name] => meter_collection
    # load_schools_metadata
  end

  def school(identifier, identifier_type = :name)
    if identifier_type == :mpan_mprn
      find_school_from_meter(identifier)
    else
      find_school(identifier, identifier_type)
    end
  end

  def meter_attributes(identifier, identifier_type = :name)
    urn = school(identifier, identifier_type).school.urn
    yaml_meter_attributes_database.fetch(urn){ {} }.fetch(:meter_attributes) { {} }
  end

  def all_schools
    @meter_collections
  end

  def match_school_names(name_matches)
    matches = []
    school_names = yaml_school_database.map { |_name, meter_collection| meter_collection[:name]}
    name_matches = [name_matches] if name_matches.is_a?(String)
    name_matches.each do |name_match|
      matches.push(school_names.select { |school_name| school_name.match?(name_match) })
    end
    matches.flatten.uniq
  end

  private

  def find_school(identifier, identifier_type)
    school = find_school_from_meter_collection(identifier, identifier_type)
    return school unless school.nil?

    school_metadata = find_school_from_yaml_database(identifier, identifier_type)
    return nil if school_metadata.nil?
    school_meter_attributes = find_meter_attributes_from_school_metadata(school_metadata)
    create_school_from_metadata(school_metadata[:name], school_metadata, school_meter_attributes)
  end

  def find_school_from_yaml_database(identifier, identifier_type)
    yaml_school_database.each_value do |school|
      return school if school[identifier_type] == identifier
    end
    nil
  end

  def find_meter_attributes_from_school_metadata(school_metadata)
    yaml_meter_attributes_database.fetch(school_metadata[:urn]){ {meter_attributes: {}, pseudo_meter_attributes: {}} }
  end

  def yaml_school_database
    @schools_metadata ||= YAML::load_file(school_metadata_filename)
    @schools_metadata.delete_if { |name, config| config.key?(:deprecated) }
    @schools_metadata
  end

  def yaml_meter_attributes_database
    puts "Loading meter attibutes from #{meter_attributes_filename}" if @meter_attributes.nil?
    @meter_attributes ||= YAML::load_file(meter_attributes_filename)
  end

  def find_school_from_meter_collection(identifier, identifier_type)
    @meter_collections.each_value do |meter_collection|
      return meter_collection if meter_collection.matches_identifier?(identifier, identifier_type)
    end
    nil
  end

  def find_school_from_meter(mpan_mprn)
    @meter_collections.each_value do |meter_collection|
      return meter_collection if meter_collection.meter?(mpan_mprn)
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

  def meter_attributes_filename
    meterreadings_cache_directory + 'meter_attributes.yml'
  end

  # load all metadata for known schools - basically school name, area, pupils, postcode, plus a list of meters etc.
  def load_schools_metadata
    load_schools(school_metadata_filename)
    check_for_duplicate_urns
  end

  def check_for_duplicate_urns
    urn_to_name_map = {}
    @meter_collections.each_value do |meter_collection|
      urn = meter_collection.urn
      name = meter_collection.name
      if urn_to_name_map.key?(urn)
        logger.error "Fatal Error: schoolsandmeters.yml has duplicate urn #{urn} school #{name}, already has same urn for #{urn_to_name_map[urn]}"
        exit
      end
      urn_to_name_map[meter_collection.urn] = meter_collection.name
    end
  end

  def load_schools(filename)
    logger.debug "Loading school and meter definitions from #{filename}"
    @schools_metadata = YAML::load_file(filename)

    ap @schools_metadata

    @schools_metadata.sort.each do |name, school_metadata|
      school_meter_attributes = find_meter_attributes_from_school_metadata(school_metadata)
      create_school_from_metadata(name, school_metadata, school_meter_attributes)
    end
  end

  def create_school_from_metadata(name, school_metadata, meter_attributes)
    gas_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :gas }
    electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :electricity }
    electric_sub_meters_meta_data = school_metadata[:meters].select { |v| %i[solar_pv exported_solar_pv].include?(v[:meter_type]) }
=begin
    aggregate_electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_heat }
    aggregate_heat_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_electricity }
    aggregate_electric_meters_metadata = school_metadata[:meters].select { |v| v[:meter_type] == :aggregated_heat }
=end
    logger.debug sprintf("\t\t%-40.40s %10.10s gas x %d electricity x %d low carbon hub meters x %d\n",
                  name, @schools_metadata[:postcode], gas_meters_metadata.length,
                  electric_meters_metadata.length, electric_sub_meters_meta_data.length)
    @meter_collections[name] = create_meter_collection(name, school_metadata, school_metadata[:meters], meter_attributes)
  end

  def create_meter_collection(school_name, school_metadata, meter_metadata, meter_attributes)
    school = create_school(school_name)

    # This was previously in meter collection
    holiday_schedule_name = school.area_name.nil? ? ScheduleDataManager::BATH_AREA_NAME : school.area_name
    temperature_schedule_name = school.area_name.nil? ? ScheduleDataManager::BATH_AREA_NAME : school.area_name
    # solar_irradiance_schedule_name = school.area_name.nil? ? ScheduleDataManager::BATH_AREA_NAME : school.area_name
    solar_pv_schedule_name = school.area_name.nil? ? ScheduleDataManager::BATH_AREA_NAME : school.area_name

    # Now we pass in the data independently
    meter_collection = MeterCollection.new(school,
      temperatures: ScheduleDataManager.temperatures(temperature_schedule_name),
      solar_pv: ScheduleDataManager.solar_pv(solar_pv_schedule_name),
      # solar_irradiation: ScheduleDataManager.solar_irradiation(solar_irradiance_schedule_name),
      grid_carbon_intensity: ScheduleDataManager.uk_grid_carbon_intensity,
      holidays: ScheduleDataManager.holidays(holiday_schedule_name),
      pseudo_meter_attributes: meter_attributes[:pseudo_meter_attributes]
    )

    puts "Got here: #{meter_collection.solar_irradiation.nil?} - need to set to nil for testing, forever"

    gas_meters = create_meters(meter_collection, school_metadata[:meters], :gas, meter_attributes[:meter_attributes])
    gas_meters.each do |gas_meter|
      meter_collection.add_heat_meter(gas_meter)
    end

    electricity_meters = create_meters(meter_collection, school_metadata[:meters], :electricity, meter_attributes[:meter_attributes])
    electricity_meters.each do |electricity_meter|
      meter_collection.add_electricity_meter(electricity_meter)
    end

    %i[solar_pv exported_solar_pv].each do |fuel_type|
      low_carbon_hub_sub_meters = create_meters(meter_collection, school_metadata[:meters], fuel_type, meter_attributes[:meter_attributes])
      low_carbon_hub_sub_meters.each do |low_carbon_hub_sub_meter|
        # added to first electric meter TODO(PH, 15Aug2019) eventually if multiple Low Carbon meters, will need grouping mechanism
        raise EnergySparksUnexpectedStateException.new, "More than one electricity meter not supported for Low Carbon Hub sub-meters" if meter_collection.electricity_meters.length != 1
        meter_collection.electricity_meters[0].sub_meters.push(low_carbon_hub_sub_meter)
      end
    end

=begin
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
=end
    logger.info "Created meter collection #{meter_collection.to_s}"
    meter_collection
  end

  def create_meters(meter_collection, meter_metadata, fuel_type, meter_attributes)
    meter_list = []

    meters_of_fuel_type = meter_metadata.select { |v| v[:meter_type] == fuel_type }

    meters_of_fuel_type.each do |meter_data|
      meter_list.push(create_empty_meter_from_meta_data(meter_collection, meter_data, meter_attributes))
    end

    meter_list
  end

=begin
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
        meter_collection.aggregated_heat_meters = create_empty_combined_meter(meter_collection, 'Combined Heat Meter', :gas, meter_data)
      end
    end
  end

  def create_empty_combined_meter(meter_collection, name, fuel_type, meter_data)
    create_empty_meter(
      meter_collection,
      name,
      Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(meter_data[:urn], fuel_type),
      fuel_type,
      meter_data[:floor_area],
      meter_data[:pupils],
      meter_data.key?(:meter_no) ? meter_data[:meter_no] : nil
    )
  end
=end
  def create_school(school_name)
    school_metadata = @schools_metadata[school_name]

    logger.debug "Creating School: #{school_name} #{school_metadata[:postcode]}"

    school = Dashboard::School.new(
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

  def create_empty_meter_from_meta_data(meter_collection, meter_data, meter_attributes)
    fuel_type = meter_data[:meter_type]
    identifier_type = %i[electricity aggregated_electricity solar_pv exported_solar_pv].include?(fuel_type) ? :mpan : :mprn

    create_empty_meter(
      meter_collection,
      meter_data[:name],
      meter_data[identifier_type],
      fuel_type,
      meter_data[:floor_area],
      meter_data[:pupils],
      meter_data.key?(:meter_no) ? meter_data[:meter_no] : nil,
      meter_attributes
    )
  end

  def create_empty_meter(meter_collection, name, identifier, fuel_type, floor_area, pupils, meter_no, all_attributes)

    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{name}"

    # front end maintains strict integer rule for mpan/mprn
    # analytics more ambiguous string or integer
    # need integer for attribute lookup
    identifier = identifier.to_i if identifier.is_a?(String) && identifier.match(/^\d+$/)

    meter_attributes = all_attributes.fetch(identifier){ {} }

    meter = Dashboard::Meter.new(
      meter_collection: meter_collection,
      amr_data: AMRData.new(fuel_type),
      type: fuel_type,
      identifier: identifier,
      name: name,
      floor_area: floor_area,
      number_of_pupils: pupils,
      meter_attributes: meter_attributes
    )

    meter.set_meter_no(meter_no) unless meter_no.nil?
    meter
  end
end
