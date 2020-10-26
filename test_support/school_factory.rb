
require_relative 'load_amr_from_bath_hacked'
# School Factory: deals with getting school, meter data from different sources:
#                 caches data so only loads once
class SchoolFactory
  METER_COLLECTION_DIRECTORY = 'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\\'
  def initialize
    @school_cache = {}  # [urn][source] = meter_collection
    @schools_meta_data = AnalysticsSchoolAndMeterMetaData.new
  end

  # e.g. meter_collection = load_school(:urn, 123456, :analytics_db) source: or :bathcsv, :bathhacked etc.
  def load_or_use_cached_meter_collection(identifier_type, identifier, source, meter_attributes_overrides: {})
    meter_collection = case source
    when :aggregated_meter_collection
      load_aggregated_meter_collection(identifier)
    when :validated_meter_collection
      load_validated_meter_collection(identifier, meter_attributes_overrides: meter_attributes_overrides)
    when :unvalidated_meter_collection
      load_unvalidated_meter_collection(identifier, meter_attributes_overrides: meter_attributes_overrides)
    when :unvalidated_meter_data
      load_unvalidated_meter_data(identifier, meter_attributes_overrides: meter_attributes_overrides)
    end
    return meter_collection unless meter_collection.nil?
    school = @schools_meta_data.school(identifier, identifier_type)
    if school.nil?
      nil
    else
      meter_collection = find_cached_school(school.urn, source)
      if meter_collection.nil?
        meter_attributes = @schools_meta_data.meter_attributes(identifier, identifier_type)
        meter_collection = load_meter_readings(school, source, meter_attributes)
        add_meter_collection_to_cache(school, source, meter_collection)
      end
      meter_collection
    end
  end

  private

  private def load_aggregated_meter_collection(school_filename)
    load_meter_collections(school_filename, 'aggregated-meter-collection-')
  end

  def load_validated_meter_collection(school_filename, meter_attributes_overrides: {})
    validated_meter_data = load_meter_collections(school_filename, 'validated-data-')
    validated_meter_collection = build_meter_collection(validated_meter_data, meter_attributes_overrides: meter_attributes_overrides)
    AggregateDataService.new(validated_meter_collection).aggregate_heat_and_electricity_meters
    validated_meter_collection
  end

  def load_unvalidated_meter_data_collection(school_filename, filename_stub, meter_attributes_overrides: {})
      unvalidated_meter_data = load_meter_collections(school_filename, filename_stub)
      ap meter_attributes_overrides
      unvalidated_meter_collection = build_meter_collection(unvalidated_meter_data, meter_attributes_overrides: meter_attributes_overrides)
      AggregateDataService.new(unvalidated_meter_collection).validate_and_aggregate_meter_data
      unvalidated_meter_collection
  end

  def load_unvalidated_meter_collection(school_filename, meter_attributes_overrides: {})
    load_unvalidated_meter_data_collection(school_filename, 'unvalidated-meter-collection-', meter_attributes_overrides: {})
  end

  def load_unvalidated_meter_data(school_filename, meter_attributes_overrides: {})
    load_unvalidated_meter_data_collection(school_filename, 'unvalidated-data-', meter_attributes_overrides: {})
  end

  # validate_and_aggregate_meter_data

  def load_meter_collections(school_filename, file_type)
    school = nil
    yaml_filename = meter_collection_filename(school_filename, file_type, '.yaml')
    marshal_filename = meter_collection_filename(school_filename, file_type, '.marshal')

    if !File.exist?(marshal_filename) || File.mtime(yaml_filename) > File.mtime(marshal_filename)
      bm = Benchmark.realtime {
        school = YAML.load_file(yaml_filename)
      }
      puts "Loaded #{yaml_filename} in #{bm.round(3)} seconds"
      save_marshal_copy(marshal_filename, school)
    else
      bm = Benchmark.realtime {
        school = load_marshal_copy(marshal_filename)
      }
      puts "Loaded #{marshal_filename} in #{bm.round(3)} seconds"
    end
    school
  end

  private def meter_collection_filename(school_filename, file_type, extension)
    METER_COLLECTION_DIRECTORY +
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

  private def build_meter_collection(data, meter_attributes_overrides: {})
    puts "Warning: loading meter attributes from :pseudo_meter_attributes rather than :meter_attributes"
    meter_attributes = data[:pseudo_meter_attributes]
    MeterCollectionFactory.new(
      temperatures: data[:schedule_data][:temperatures],
      solar_pv: data[:schedule_data][:solar_pv],
      solar_irradiation: data[:schedule_data][:solar_irradiation],
      grid_carbon_intensity: data[:schedule_data][:grid_carbon_intensity],
      holidays: data[:schedule_data][:holidays]
    ).build(
      school_data: data[:school_data],
      amr_data: data[:amr_data],
      pseudo_meter_attributes: meter_attributes.merge(meter_attributes_overrides)
    )
  end

  def find_cached_school(urn, source)
    @school_cache.dig(urn, source)
  end

  def add_meter_collection_to_cache(school, source, meter_collection)
    (@school_cache[school.urn] ||= {})[source] = meter_collection
  end

  def load_meter_readings(school, source, meter_attributes)
    school_copy = school.deep_dup
    bm = Benchmark.realtime {
      loader = MeterReadingsDownloadBase.meter_reading_factory(source, school_copy, meter_attributes)
      loader.load_meter_readings
    }
    puts "loaded marshal meter readings in #{bm.round(5)}"
    school_copy
  end

end
