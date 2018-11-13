require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromSheffieldCSV < MeterReadingsDownloadCSVBase
  include Logging

  def initialize(meter_collection)
    super(meter_collection)
    @delimiter = ','
  end

  def load_meter_readings
    load_british_gas_readings
    load_npower_readings
  end

  private

  def load_british_gas_readings
    logger.info "Loading data from #{gas_filename}"

    @file = File.open(gas_filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    lines.each do |line|
      begin
        meter_id, fuel_type, name, one_days_data = process_line_british_gas(:gas, @column_names, line)
        unless meter_id.nil?
          add_reading_to_meter_collection(meter_id, :gas, nil, one_days_data)
        end
      rescue StandardError => _e
        logger.info "Unable to process line #{line}"
      end
    end
  end

  def load_npower_readings
    logger.info "Loading data from #{electricity_filename}"

    @file = File.open(electricity_filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    lines.each do |line|
      begin
        meter_id, fuel_type, name, one_days_data = process_line_npower(:electricity, @column_names, line)
        unless meter_id.nil?
          add_reading_to_meter_collection(meter_id, :electricity, nil, one_days_data)
        end
      rescue StandardError => _e
        logger.info "Unable to process line #{line}"
      end
    end
  end

  def process_line_british_gas(_type, _column_names, line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = Date.parse(line_data[column_index(@column_names, 'read_date')])
    fuel_type = :gas
    mpan_or_mprn = line_data[column_index(@column_names, 'meter_identifier')].to_s
    halfhour_kwh_x48 = line_data[column_index(@column_names, 'hh01')..column_index(@column_names, 'hh48')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [mpan_or_mprn, fuel_type, nil, one_days_data]
  end

  def process_line_npower(_type, _column_names, line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = Date.parse(line_data[column_index(@column_names, 'ConsumptionDate')])
    fuel_type = :electricity
    mpan_or_mprn = line_data[column_index(@column_names, 'MPAN')].to_s
    halfhour_kwh_x48 = line_data[column_index(@column_names, 'kWh_1')..column_index(@column_names, 'kWh_48')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [mpan_or_mprn, fuel_type, nil, one_days_data]
  end

  def filename
    throw EnergySparksUnexpectedStateException.new('No single file name for loading Sheffield Schools')
  end

  def gas_filename
    directory + 'British Gas (GAS) Historical HHD for Bankwood Primary 031018.csv'
  end

  def electricity_filename
    directory + 'Npower (ELEC) Historical HHD for Bankwood Primary 031018.csv'
  end

  def subdirectory
    'Sheffield'
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
end
