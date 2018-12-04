# Not sure where this should go in the source code hierarchy
# school_factory.rb - but thats in 'test support'? TODO(PH,JJ,1Dec2018)
class AnalyticsLoadSchools
  def self.load_schools(school_list)
    # school = $SCHOOL_FACTORY.load_school(school_name)
    schools = []
    school_list.each do |school_attribute|
      identifier_type, identifier = school_attribute.first
      
      bm = Benchmark.measure {
        school = $SCHOOL_FACTORY.load_or_use_cached_meter_collection(identifier_type, identifier, :analytics_db)
        schools.push(school)
      }
      Logging.logger.info "Loaded School: #{identifier_type} #{identifier} in #{bm.to_s}"
    end
    schools
  end
end
