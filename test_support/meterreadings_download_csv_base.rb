require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
require_relative './meterreadings_download_baseclass.rb'
# Base class for downloading/storing meter readings from csv/excel type sources
# provides support code for file loading
class MeterReadingsDownloadCSVBase < MeterReadingsDownloadBase
  include Logging

  def initialize(meter_collection)
    super(meter_collection)
  end

  protected

  def substitute_unwanted_characters(line)
    line.gsub('"', '')
  end

  def column_index(column_names, name)
    column_names.index(name)
  end

  def process_readings(type, column_names, lines)
    lines.each do |line|
      meter_id, fuel_type, name, one_days_data = process_line(type, column_names, line)
      unless meter_id.nil?
        add_reading_to_meter_collection(meter_id, fuel_type, name, one_days_data)
      end
    end
  end

  def meter_filenames(list_of_files, school_name, fuel_type)
    filename_definition = list_of_files[school_name]
    if filename_definition.key?(fuel_type)
      filenames = filename_definition[fuel_type]
      filenames = [filenames] if filenames.is_a?(String)
      filenames
    else
      nil
    end
  end

  def add_reading_to_meter_collection(meter_id, fuel_type, name, one_days_data)
    meter = @meter_collection.meter?(one_days_data.meter_id)
    if meter.nil?
      meter = create_empty_meter(one_days_data.meter_id, fuel_type, name)
      if fuel_type == :gas
        @meter_collection.add_heat_meter(meter)
      elsif fuel_type == :electricity
        @meter_collection.add_electricity_meter(meter)
      end
    end

    meter = @meter_collection.meter?(one_days_data.meter_id)
    meter.amr_data.add(one_days_data.date, one_days_data)
  end

  def create_empty_meter(identifier, fuel_type, name)
    identifier_type = fuel_type == :electricity ? :mpan : :mprn
    logger.debug "Creating Meter with no AMR data #{identifier} #{fuel_type} #{name}"
    meter_attributes = MeterAttributes.for(identifier, @meter_collection.area_name)

    meter = Dashboard::Meter.new(
      meter_collection: meter_collection,
      amr_data: AMRData.new(fuel_type),
      type: fuel_type,
      identifier: identifier,
      name: name,
      floor_area: @meter_collection.floor_area,
      number_of_pupils: @meter_collection.number_of_pupils,
      meter_attributes: meter_attributes
    )

  end
end
