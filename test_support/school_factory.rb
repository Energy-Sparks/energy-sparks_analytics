
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
