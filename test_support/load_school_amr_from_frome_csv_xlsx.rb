require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
require_relative './meterreadings_download_csv_base'
require 'roo'
# creates meter_collection from csv file for Bath school
class LoadSchoolFromFromeFiles < MeterReadingsDownloadCSVBase
  include Logging

  @@frome_filenames = {
    'Christchurch First School' => {
      gas: [ 'E200 CHRISTCHURCH FIRST SCHOOL 13605606.csv' ]
    },
    'Frome College' => {
      electricity: [ 'E201 FROME COLLEGE 2000027481429.csv' ]
    },
    'Critchill School' => {
      electricity: [ 'E214 FROME CRITCHILL SCHOOL 2000025766279.csv' ],
      gas: [ 'E214 FROME CRITCHILL SCHOOL 13610902.csv' ]
    },
    'Hayesdown First School' => {
      electricity: [ 'E204 HAYESDOWN FIRST SCHOOL 2000054408180.csv' ]
    },
    'Oakfield School' => {
      electricity: [ 'E208 Oakfield School 2000027949134.csv' ],
      gas: [ 'E208 Oakfield School 13610307.csv', 'E208 Oakfield School 13610408.csv' ]
    },
    'Selwood Academy' => {
      electricity: [ 'E212 Selwood Academy 2000051663623.csv' ],
      gas: [ 'E212 Selwood Academy 74020900.csv', 'E212 Selwood Academy 77409304.csv' ]
    },
    'St Johns First School' => {
      electricity: [ 'E210 ST JOHNS FIRST SCHOOL 2000025929961.csv' ],
      gas: [ 'E210 ST JOHNS FIRST SCHOOL 13610610.csv', 'E210 ST JOHNS FIRST SCHOOL 13610801.csv' ]
    },
    'St Louis First School' => {
      electricity: [ 'E211 ST LOUIS FIRST SCHOOL 2000025706400.csv'],
      gas: [ 'E211 ST LOUIS FIRST SCHOOL 19161200.csv' ]
    },
    'Trinity First School' => {
      electricity: ['E206 TRINITY FIRST SCHOOL 2000025766288.csv'],
      gas: ['10545307 01-01-2016 to 31-12-2016.xlsx', '10545307 01-01-2017 to 31-12-2017.xlsx', '10545307 01-01-2018 to 19-03-2018.csv']
    },
    'Vallis First School' => {
      electricity: [ 'E216 VALLIS FIRST SCHOOL 2000025901813.csv' ],
      gas: [ 'E216 VALLIS FIRST SCHOOL 13625803.csv', 'E216 VALLIS FIRST SCHOOL 13625904.csv' ]
    }

  }
  def initialize(meter_collection)
    super(meter_collection)
    @meter_collection = meter_collection
    @delimiter = ','
  end

  def load_meter_readings
    gas_filenames = meter_filenames(@@frome_filenames, @meter_collection.name, :gas)

    unless gas_filenames.nil?
      gas_filenames.each do |gas_filename|
        type, column_names, data = load_file( directory + gas_filename)
        process_readings(type, column_names, data)
      end
    end

    electricity_filenames = meter_filenames(@@frome_filenames, @meter_collection.name, :electricity)
    unless electricity_filenames.nil?
      electricity_filenames.each do |electricity_filename|
        type, column_names, data = load_file( directory + electricity_filename)
        process_readings(type, column_names, data)
      end
    end
  end
=begin
  def load_meter_readings
    logger.info "Loading data from #{meterreadings_cache_directory}"

    (@meter_collection.heat_meters + @meter_collection.electricity_meters).each do |meter|

      files = list_of_files(meter.mpan_mprn)

      files.each do |filename|
        type, column_names, data = load_file(filename)
        process_readings(type, column_names, data)
      end
    end

    logger.info 'Completed loading of data from csv/xlsx files'
    # AggregateDataService.new(@meter_collection).validate_and_aggregate_meter_data
  end
=end
  private

  def load_file(filename)
    logger.info "Loading file #{filename}"
    
    if File.extname(filename) == '.csv'
      logger.info 'csv file'
      return read_csv(filename)
    elsif File.extname(filename) == '.xlsx'
      logger.info 'xlsx file'
      return read_xlsx(filename)
    end
  end

  def read_csv(filename)
    @file = File.open(filename)

    column_names = substitute_unwanted_characters(@file.readline.chomp).split(@delimiter)

    lines = @file.readlines.map(&:chomp)

    line_data = []

    lines.each do |line|
      line_data.push(substitute_unwanted_characters(line).split(@delimiter))
    end

    logger.info "Downloaded #{lines.length} meter readings"
    [:csv, column_names, line_data]
  end

  def read_xlsx(filename)
    workbook = Roo::Spreadsheet.open filename
    worksheets = workbook.sheets
    puts "Found #{worksheets.count} worksheets"

    column_names = nil
    lines = []

    worksheets.each do |worksheet|
      puts "Reading: #{worksheet}"
      num_rows = 0
      workbook.sheet(worksheet).each_row_streaming do |row|
        if num_rows == 0
          column_names = row.map { |cell| cell.value }
        else
         lines.push(row.map { |cell| cell.value })
        end
        num_rows += 1
      end
      puts "Read #{num_rows} rows" 
    end

    [:xlsx, column_names, lines]
  end

  def list_of_files(meter_no)
    Dir["#{directory}/#{meter_no}*"]
  end

  def process_line(type, column_names, line_data)
    mpan_or_mprn = line_data[column_index(column_names, 'Site Id')].to_s
    meter_id = line_data[column_index(column_names, 'Meter Number')]

    halfhour_kwh_x48 = nil
    date = nil
    if type == :xlsx
      halfhour_kwh_x48 = line_data[column_index(column_names, 0)..column_index(column_names, 84600)].map(&:to_f)
      date = line_data[column_index(column_names, 'Reading Date')]
    else
      halfhour_kwh_x48 = line_data[column_index(column_names, '00:00')..column_index(column_names, '23:30')].map(&:to_f)
      date = convert_date(line_data[column_index(column_names, 'Reading Date')]) 
      # date = Date.parse(line_data[column_index(column_names, 'Reading Date')])
    end

    if halfhour_kwh_x48.length == 47 && [Date.new(2018, 11, 6), Date.new(2018, 11, 11)].include?(date)
      halfhour_kwh_x48.push(halfhour_kwh_x48.last) # the data set seems to have the last half hour missing
    end

    logger.error "Got out of date range #{date}" if date > Date.new(2020, 1, 1)

    if halfhour_kwh_x48.nil? || halfhour_kwh_x48.empty? || !check_date(date)
      logger.info "Warning: missing meter readings for #{mpan_or_mprn} on #{date}"
      [nil, nil, nil, nil]
    elsif halfhour_kwh_x48.length != 48
      logger.info "Warning: shortage of meter readings on day for #{mpan_or_mprn} on #{date} count #{halfhour_kwh_x48.length}"
      logger.info "#{line_data}"
      [nil, nil, nil, nil]
    else
      one_days_data = OneDayAMRReading.new(mpan_or_mprn, date, 'ORIG', nil, DateTime.now, halfhour_kwh_x48)

      [meter_id, nil, nil, one_days_data]
    end
  end

  def subdirectory
    'Frome'
  end

  def convert_date(date_string)
    date = Date.strptime(date_string, '%d/%m/%Y')
    if !check_date(date)
      date = Date.strptime(date_string, '%d/%m/%y')
      if !check_date(date)
        logger.error "Problem reading date #{date} from #{date_string}"
      end
    end
    date
  end

  def check_date(date)
    if date.year > 2025 || date.year < 2000
      return false
    end
    true
  end
end
