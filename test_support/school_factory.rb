
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
    puts "Got here: #{source}"
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

  private def aggregate_meter_collection_filename(school_part)
    'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\aggregated-meter-collection-'+ school_part + '.yaml'
  end

  private def load_aggregated_meter_collection
    filename = 'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\aggregated-meter-collection-trinity-c-of-e-first-school.yaml'
    filename = 'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\aggregated-meter-collection-farr-primary-school.yaml'
    filename = 'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\aggregated-meter-collection-king-edward-vii-upper-school.yaml'
    filename = 'C:\Users\phili\OneDrive\ESDev\energy-sparks_analytics\AggregatedMeterCollections\aggregated-meter-collection-whiteways-primary-school.yaml'
    filename = aggregate_meter_collection_filename('whiteways-primary-school')
    return load_marshal_copy(marshal_filename(filename)) if File.exist?(marshal_filename(filename))

    school = nil

    

    bm = Benchmark.realtime {
      school = YAML.load_file(filename)
    }
    puts "Loaded #{filename} in #{bm.round(3)} seconds"

    bm = Benchmark.realtime {
      save_marshal_copy(filename, school)
    }
    puts "saved marshal version in #{bm.round(5)}"
    school
  end

  private def marshal_filename(filename)
    Pathname(filename).sub_ext('.marshal')
  end

  private def save_marshal_copy(filename, school)
    File.open(marshal_filename(filename), 'wb') { |f| f.write(Marshal.dump(school)) }
  end

  private def load_marshal_copy(marshal_filename)
    school = nil
    bm = Benchmark.realtime {
      school = Marshal.load(File.open(marshal_filename))
    }
    puts"loaded marshal version in #{bm.round(5)}"
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
