
require_relative 'load_amr_from_bath_hacked'
# School Factory: deals with getting school, meter data from different sources:
#                 caches data so only loads once
class SchoolFactory
  def initialize
    @school_cache = {}  # [urn][source] = meter_collection
    @schools_meta_data = AnalysticsSchoolAndMeterMetaData.new
  end

  # e.g. meter_collection = load_school(:urn, 123456, :analytics_db) source: or :bathcsv, :bathhacked etc.
  def load_or_use_cached_meter_collection(identifier_type, identifier, source)
    return load_aggregated_meter_collection if source == :aggregated_meter_collection
    return load_validated_meter_collection  if source == :load_validated_meter_collection
    return load_unvalidated_meter_collection  if source == :load_unvalidated_meter_collection
    school = @schools_meta_data.school(identifier, identifier_type)
    if school.nil?
      nil
    else
      meter_collection = find_cached_school(school.urn, source)
      if meter_collection.nil?
        meter_collection = load_meter_readings(school, source)
        add_meter_collection_to_cache(school, source, meter_collection)
      end
      meter_collection
    end
  end

  private

  private def load_aggregated_meter_collection
    school_filename = [
      'whiteways-primary-school',
      'trinity-c-of-e-first-school'
    ][0]

    load_meter_collections(school_filename, 'aggregated-meter-collection-')
  end

  def load_validated_meter_collection
    school_filename = 'st-marks-c-of-e-school'
    validated_meter_data = load_meter_collections(school_filename, 'validated-data-')
    validated_meter_collection = MeterCollectionFactory.build(validated_meter_data)
    AggregateDataService.new(validated_meter_collection).aggregate_heat_and_electricity_meters
    validated_meter_collection
  end

  def load_unvalidated_meter_collection
    school_filename = 'freshford-church-school'
    unvalidated_meter_data = load_meter_collections(school_filename, 'unvalidated-data-')
    unvalidated_meter_collection = MeterCollectionFactory.build(unvalidated_meter_data)
    AggregateDataService.new(unvalidated_meter_collection).validate_and_aggregate_meter_data
    unvalidated_meter_collection
  end

  # validate_and_aggregate_meter_data

  def load_meter_collections(school_filename, file_type)
    school = nil
    yaml_filename = meter_collection_filename(school_filename, file_type, '.yaml')
    marshal_filename = meter_collection_filename(school_filename, file_type, '.marshal')

    validated_meter_collection = if File.exist?(marshal_filename)
      bm = Benchmark.realtime {
        school = load_marshal_copy(marshal_filename)
      }
      puts "Loaded #{marshal_filename} in #{bm.round(3)} seconds"
    else
      bm = Benchmark.realtime {
        school = YAML.load_file(yaml_filename)
      }
      puts "Loaded #{yaml_filename} in #{bm.round(3)} seconds"
      save_marshal_copy(marshal_filename, school)
    end
    school
  end

  private def meter_collection_filename(school_filename, file_type, extension)
    'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\\' +
     file_type + school_filename + extension
  end

  private def save_marshal_copy(filename, school)
    File.open(filename, 'wb') { |f| f.write(Marshal.dump(school)) }
    school
  end

  private def load_marshal_copy(marshal_filename)
    school = nil
    bm = Benchmark.realtime {
      school = Marshal.load(File.open(marshal_filename))
    }
    puts "loaded marshal version in #{bm.round(5)}: #{marshal_filename}"
    school
  end

  def find_cached_school(urn, source)
    @school_cache.dig(urn, source)
  end

  def add_meter_collection_to_cache(school, source, meter_collection)
    (@school_cache[school.urn] ||= {})[source] = meter_collection
  end

  def load_meter_readings(school, source)
    school_copy = school.deep_dup
    loader = MeterReadingsDownloadBase.meter_reading_factory(source, school_copy)
    loader.load_meter_readings
    school_copy
  end
end
