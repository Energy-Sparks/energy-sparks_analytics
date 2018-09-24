require 'yaml'
require 'benchmark'
require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# Local meter readings database load and save = one yml or marshal file per school
# - this stores meter readings - an array of OneDayAMRReading's in local yml/marshal files
# - loads and stores data into a meter_collection 
# - uses schoolsandmeters.yml to determine meter_collection metadata

class LocalAnalyticsMeterReadingDB
  include Logging

  def initialize(school)
    @meter_collection = school
  end

  def load_meter_readings
    load_meter_collection(@meter_collection.name)
    AggregateDataService.new(@meter_collection).validate_and_aggregate_meter_data
  end

  private

  def meterreadings_cache_directory
    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= File.join(File.dirname(__FILE__), '../MeterReadings/')
    ENV['CACHED_METER_READINGS_DIRECTORY'] 
  end

  def load_meter_collection(school_name)
    yml_filename = meter_readings_yml_filename(school_name)
    marshal_filename = meter_readings_marshal_filename(school_name)
    logger.info "Loading meter readings for #{school_name}"

    meter_readings = nil

    if File.exist?(marshal_filename)
      bm = Benchmark.measure {
        meter_readings = Marshal.load(File.open(marshal_filename))
      }
      logger.info "Loading marshal data took #{bm.to_s}"
    elsif File.exist?(yml_filename)
      bm = Benchmark.measure {
        meter_readings = YAML::load_file(yml_filename)
      }
      logger.info "Loading yml data took #{bm.to_s}"
      File.open(marshal_filename, 'wb') do |f|
        f.write Marshal.dump(meter_readings)
      end
    else
      logger.info("No local marshal or yml file for #{school_name} to load metere readings from")
      return
    end

    bm = Benchmark.measure {
      populate_meter_collection_from_readings(meter_readings)
    }
    logger.info "Processing meter readings took #{bm.to_s}"
  end

  def populate_meter_collection_from_readings(meter_readings)
    id_count = {}
    meter_readings.each do |meter_reading|
      meter_id = meter_reading.meter_id
      id_count[meter_id] = 0 unless id_count.key?(meter_id)
      id_count[meter_id] += 1
      meter = @meter_collection.meter?(meter_id)
      if meter.nil?
        logger.error "Meter #{meter_id} not found"
      else
        meter.amr_data.add(meter_reading.date, meter_reading)
      end
    end
    id_count.each do |identifier, count|
      logger.debug "loaded #{count} meter readings for #{identifier}"
    end
  end

  def meter_readings_filename_base(school_name)
    meterreadings_cache_directory + school_name + ' - energy sparks amr data analytics meter readings'
  end

  def meter_readings_yml_filename(school_name)
    meter_readings_filename_base(school_name) + '.yml'
  end

  def meter_readings_marshal_filename(school_name)
    meter_readings_filename_base(school_name) + '.marshal'
  end
end
