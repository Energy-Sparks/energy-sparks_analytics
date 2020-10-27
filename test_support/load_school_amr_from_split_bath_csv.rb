require_relative '../app/services/aggregation_service.rb'
require_relative '../app/models/meter_collection'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromBathSplitCSVFile < MeterReadingsDownloadCSVBase
  include Logging

  def initialize(meter_collection, meter_attributes)
    super(meter_collection, meter_attributes)
    @delimiter = ','
  end

  def load_meter_readings
    logger.info "Loading data from #{filename}"

    @file = File.open(filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    process_readings(nil, @column_names, lines)
  end

  private

  def process_line(_type, _column_names, line)
    line_data = substitute_unwanted_characters(line).split(@delimiter)
    date = Date.parse(line_data[column_index(@column_names, 'Date')])
    fuel_type = fuel_type(line_data[column_index(@column_names, 'Type')])
    mpan_or_mprn = line_data[column_index(@column_names, 'M1_Code1')].to_s
    meter_id = line_data[column_index(@column_names, 'M1_Code2')]
    location = line_data[column_index(@column_names, 'Location')]
    halfhour_kwh_x48 = line_data[column_index(@column_names, '[00:30]')..column_index(@column_names, '[24:00]')].map(&:to_f)

    one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)
    [meter_id, fuel_type, location, one_days_data]
  end

  def filename
    directory + 'amr data for building at postcode ' + @postcode + '.csv'
  end

  def subdirectory
    'Bath'
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
