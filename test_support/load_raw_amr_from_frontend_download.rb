require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
require_relative './meterreadings_download_csv_base'
require 'fileutils'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromRawFrontEndDownload < MeterReadingsDownloadCSVBase
  include Logging

  def initialize(meter_collection)
    super(meter_collection)
    @delimiter = ','
    @raw_meter_readings = LoadRawFrontEndMeterReadings.new
    @raw_meter_readings.load_data
  end

  def load_meter_readings
    @meter_collection.all_real_meters.each do |meter|
      load_meter_amr_data(meter)
    end
    log_inconsistent_data if !meter_data_consistent?
  end

  def meter_data_consistent?
    all_meter_readings? && all_meters?
  end

  def log_inconsistent_data
    logger.info "mpan_mprn #{missing_meters.join(', ')} not set up in yaml database" if !all_meters?
    logger.info "mpan_mprn #{missing_meter_readings.join(', ')} not available in raw readings download from from end" if !all_meter_readings?
  end

  private

  def all_meter_readings?
    !missing_meter_readings.empty?
  end

  def missing_meter_readings
    @meter_collection.all_real_meters.select { |meter| !@raw_meter_readings.list_of_mpan_mprns.include?(meter.mpan_mprn) }
  end

  def all_meters?
    missing_meters.empty?
  end

  def missing_meters
    mpan_mprns_for_school = @raw_meter_readings.mpan_mprn_to_urn_map.select { |mpan_mprn, urn| urn == @meter_collection.urn }.keys
    mpan_mprns_for_school.select { |mpan_mprn| !@meter_collection.meter?(mpan_mprn) }
  end

  def load_meter_amr_data(meter)
    readings = @raw_meter_readings.meter_readings(meter.mpan_mprn)
    readings.each do |date, one_days_data|
      meter.amr_data.add(date, one_days_data)
    end
    logger.info "Loaded meter readings: #{meter.to_s}"
  end
end
