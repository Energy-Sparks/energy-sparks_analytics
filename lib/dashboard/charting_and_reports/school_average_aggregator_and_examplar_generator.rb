require 'require_all'
# Given a list of 'average school's creates an average school
# also generates an exemplar school
#

class AverageSchoolAggregator
  include Logging

  attr_reader :aggregation_definition

  # aggregation_definition example:
  #
  # aggregation_definition = {
  #   name:       'Average School',
  #   urn:        123456789,
  #   floor_area: 1000.0,
  #   pupils:     200,
  #   schools: [
  #               { urn: 109089 },  # Paulton Junior
  #               { urn: 109328 },  # St Marks
  #               { urn: 109005 },  # St Johns
  #               { urn: 109081 }   # Castle
  #   ]  
  # }
  def initialize(aggregation_definition)
    @aggregation_definition = aggregation_definition
  end

  def calculate
    schools = self.class.load_schools(@aggregation_definition[:schools])

    average_school = create_meter_collection(
      @aggregation_definition[:name],
      @aggregation_definition[:urn],
      @aggregation_definition[:floor_area],
      @aggregation_definition[:pupils]
    )

    bm = Benchmark.measure {
      average_amr_data(average_school, schools, :aggregated_electricity)
      average_amr_data(average_school, schools, :aggregated_heat)
    }
    logger.info("Created average school from #{schools.length} schools in #{bm.to_s}")
  end

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

  private

  # average, scaled back to average school's floor_area (gas) or pupils (electricity)
  def average_amr_data(average_school, schools, fuel_type)
    amr_data_count = {}
    average_school_meter = aggregated_meter(average_school, fuel_type)
    average_amr_data = average_school_meter.amr_data
    

    schools.each do |school|
      meter = aggregated_meter(school, fuel_type)
      amr_data = meter.amr_data
      scaling_factor = fuel_type == :aggregated_electricity ? (1 / school.number_of_pupils) : (1 / school.floor_area)

      (amr_data.start_date..amr_data.end_date).each do |date|
        average_amr_data.add(date, OneDayAMRReading.zero_reading(0, date, 'AGGR')) if !average_amr_data.key?(date)
        average_amr_data[date] += OneDayAMRReading.scale(amr_data[date], scaling_factor)
        amr_data_count[date] = 0 if !amr_data_count.key?(date)
        amr_data_count[date] += 1
      end
    end

    scaling_factor = fuel_type == :aggregated_electricity ? (1 / average_school.number_of_pupils) : (1 / average_school.floor_area)

    (average_amr_data.start_date..average_amr_data.end_date).each do |date|
      average_amr_data.add(date, OneDayAMRReading.scale(average_amr_data[date], scaling_factor / amr_data_count[date]))
    end
  end

  def aggregated_meter(meter_collection, fuel_type)
    fuel_type == :aggregated_electricity ? meter_collection.aggregated_electricity_meters : meter_collection.aggregated_heat_meters
  end

  def create_meter_collection(name, urn, floor_area, pupils)
    logger.debug "Creating School: #{name}"

    na = 'Not Applicable'

    school = School.new(name, na, floor_area, pupils, :primary, na, urn, na)

    meter_collection = MeterCollection.new(school)

    meter_collection.aggregated_electricity_meters = create_empty_meter(meter_collection, name + ' Electricity', :aggregated_electricity, floor_area, pupils, urn)
    
    meter_collection.aggregated_heat_meters = create_empty_meter(meter_collection, name + ' Gas', :aggregated_heat, floor_area, pupils, urn)

    meter_collection
  end

  def create_empty_meter(meter_collection, name, fuel_type, floor_area, pupils, urn)
    identifier = Meter.synthetic_combined_meter_mpan_mprn_from_urn(urn, fuel_type)

    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{name}"

    meter = Meter.new(
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
  end
end