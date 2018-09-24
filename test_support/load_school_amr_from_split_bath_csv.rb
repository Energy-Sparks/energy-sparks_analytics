require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromBathSplitCSVFile
  include Logging

  def initialize(meter_collection, school_name, postcode, delimiter = ',')
    @meter_collection = meter_collection
    @school_name = school_name
    @postcode = postcode
    @delimiter = delimiter
  end

  def load_data
    logger.info "Loading data from #{filename}"

    @file = File.open(filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    process_readings(lines)

    AggregateDataService.new(@meter_collection).validate_and_aggregate_meter_data
  end

  private

  def process_readings(lines)
    lines.each do |line|
      meter_id, fuel_type, name, one_days_data = process_line(line)
      add_reading_to_meter_collection(meter_id, fuel_type, name, one_days_data)
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

    meter = Meter.new(
      @meter_collection,
      AMRData.new(fuel_type),
      fuel_type,
      identifier,
      name,
      @meter_collection.floor_area,
      @meter_collection.number_of_pupils,
      nil, # solar pv
      nil # storage heater
    )
  end

  def column_index(name)
    @column_names.index(name)
  end

  def fuel_type(fuel_string)
    case fuel_string.downcase
    when 'electricity'
      :electricity
    when 'gas'
      :gas
    else
      :unknown
    end
  end

  def substitute_unwanted_characters(line)
    line.gsub('"', '')
  end

  def process_line(line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = Date.parse(line_data[column_index('Date')])
    fuel_type = fuel_type(line_data[column_index('Type')])
    mpan_or_mprn = line_data[column_index('M1_Code1')].to_s
    meter_id = line_data[column_index('M1_Code2')]
    location = line_data[column_index('Location')]
    halfhour_kwh_x48 = line_data[column_index('[00:30]')..column_index('[24:00]')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [meter_id, fuel_type, location, one_days_data]
  end

  def filename
    meterreadings_cache_directory + 'Bath/' + 'amr data for building at postcode ' + @postcode + '.csv'
  end

  def meterreadings_cache_directory
    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= File.join(File.dirname(__FILE__), '../MeterReadings/')
    ENV['CACHED_METER_READINGS_DIRECTORY'] 
  end
end
