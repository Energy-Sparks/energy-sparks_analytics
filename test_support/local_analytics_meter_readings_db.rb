require 'yaml'
require 'benchmark'
require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# Local meter readings database load and save = one yml or marshal file per school
# - this stores meter readings - an array of OneDayAMRReading's in local yml/marshal files
# - loads and stores data into a meter_collection 
# - uses schoolsandmeters.yml to determine meter_collection metadata

class LocalAnalyticsMeterReadingDB < MeterReadingsDownloadBase
  include Logging

  def initialize(meter_collection)
    super(meter_collection)
  end

  def load_meter_readings
    load_meter_collection(@meter_collection.name)
    AggregateDataService.new(@meter_collection).aggregate_heat_and_electricity_meters
  end

  def save_meter_readings
    save_meter_collection(@meter_collection.name)
  end

  private
=begin
  def meterreadings_cache_directory
    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= File.join(File.dirname(__FILE__), '../MeterReadings/')
    ENV['CACHED_METER_READINGS_DIRECTORY'] 
  end
=end
  def save_meter_collection(school_name)
    yml_filename = meter_readings_yml_filename(school_name)
    marshal_filename = meter_readings_marshal_filename(school_name)

    all_meter_readings = []

    # all_meters = @meter_collection.all_meters
    all_meters = @meter_collection.electricity_meters + @meter_collection.heat_meters

    all_meters.each do |meter|
      # sort so debugging data in YAML easier
      readings = meter.amr_data.values.sort_by {|reading| reading.date}
      all_meter_readings.concat(readings)
    end

    logger.info "Saving #{all_meter_readings.length} meter readings to YML #{yml_filename}"
    File.open(yml_filename, 'w') { |f| f.write(YAML.dump(all_meter_readings)) }

    logger.info "Saving #{all_meter_readings.length} meter readings to marshal #{marshal_filename}"
    File.open(marshal_filename, 'wb') { |f| f.write(Marshal.dump(all_meter_readings)) }
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
      logger.info("No local marshal or yml file for #{school_name} to load meter readings from")
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
        logger.error "Meter #{meter_id} not found (1)"
      else
        meter.amr_data.add(meter_reading.date, meter_reading)
      end
    end
    id_count.each do |identifier, count|
      logger.debug "loaded #{count} meter readings for #{identifier}"
    end

    @meter_collection.all_meters.each do |meter|
      meter.amr_data.set_long_gap_boundary
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
