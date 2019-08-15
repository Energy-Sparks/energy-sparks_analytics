require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
require_relative './meterreadings_download_csv_base'
require 'fileutils'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromFrontEndDownload < MeterReadingsDownloadCSVBase
  include Logging

  def initialize(meter_collection)
    super(meter_collection)
    @delimiter = ','
  end

  def load_meter_readings
    @meter_collection.electricity_meters.each do |meter|
      load_meter_amr_data(meter)
    end
    @meter_collection.heat_meters.each do |meter|
      load_meter_amr_data(meter)
    end
  end

  private

  def load_meter_amr_data(meter)
    filename = move_file_to_school_subdirectory(meter.mpan_mprn)
    logger.info "Loading meter readings from #{filename}"

    @file = File.open(filename)

    @column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    logger.info "Downloaded #{lines.length} meter readings"

    process_readings(meter, @column_names, lines)
  end

  # its easiest to manually export all the meter reading files to a single directory
  # but then better when running this program to move the processed files to a school
  # specific subdirectory
  def move_file_to_school_subdirectory(mpan_or_mprn)
    school_directory = directory + '/' + @meter_collection.name
    if !File.directory?(school_directory)
      Dir.mkdir(school_directory)
    end
    old_filepath = directory + filename(mpan_or_mprn)
    new_filepath = school_directory + '/' + filename(mpan_or_mprn)
    if File.file?(old_filepath)
      FileUtils.mv(old_filepath, new_filepath)
    end
    new_filepath
  end

  def process_readings(meter, column_names, lines)
    lines.each do |line|
      process_line(meter, column_names, line.split(@delimiter))
    end
  end

  def process_line(meter, column_names, line)
    # column names = Reading Date,	One Day Total kWh,	Status,	SubstituteDate,	 00:30,......24:00
    #                 (note 00:30 only has leading space. 24:00 appears as 24:00.00 in csv on Excel 2016)
    date_str = line[column_index(@column_names, 'Reading Date')]
    date = Date.parse(date_str)
    one_day_total_kwh = line[column_index(@column_names, 'One Day Total kWh')].to_f
    bad_data_status = line[column_index(@column_names, 'Status')]
    sub_date_str = line[column_index(@column_names, 'Substitute Date')]
    sub_date = sub_date_str.length > 4 ? Date.parse(sub_date_str) : nil
    halfhour_kwh_x48 = line[column_index(@column_names, '00:30')..column_index(@column_names, '00:00')].map(&:to_f)
    calced_day_kwh = halfhour_kwh_x48.inject(:+)
    log.info "Date #{date} sum of half hour readings #{calced_day_kwh} != provided total #{one_day_total_kwh}" if calced_day_kwh != one_day_total_kwh
    one_days_data = OneDayAMRReading.new(meter.mpan_mprn, date, bad_data_status, sub_date, DateTime.now, halfhour_kwh_x48)
    meter.amr_data.add(date, one_days_data)
  end

  def filename(mpan_or_mprn)
    "meter-amr-readings-#{mpan_or_mprn}.csv"
  end

  def subdirectory
    'Front End CSV Downloads'
  end
end