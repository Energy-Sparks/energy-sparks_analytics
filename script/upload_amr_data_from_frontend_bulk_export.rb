# takes single large CSV file containing all meter readings downloaded from front end
# and splits the data up into one file per meter reading, to help management/debugging
# attempts to work out which meters are not configured in meter_collection/school YAML
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require './test_support/meterreadings_download_baseclass.rb'

module Logging
  # @logger = Logger.new('log/bulk-amr-upload ' + Time.now.strftime('%H %M') + '.log')
  # @logger = Logger.new(STDOUT)
  # @logger = Logger.new(@custom_logger)
  @logger = Logger.new('log/bulk-amr-upload ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

class CSVSplitter
  attr_reader :data
  def initialize(source_file, destination_directory, split_column_name, delimiter)
    @source_file = source_file
    @destination_directory = destination_directory
    @split_column_name = split_column_name
    @delimiter = delimiter
  end

  def split
    logger.info "Downloading data from #{@source_file}"
    @file = File.open(@source_file)
    read_header
    @split_column_number = @column_names.index(@split_column_name)
    load_data_and_group
    # data_statistics
    save_files
  end

  def read_header
    @original_header = @file.readline
    @column_names = @original_header.gsub('"', '').split(@delimiter)
  end

  def load_data_and_group
    count = 0
    @data = {}  # hash split on column_name to array of lines
    @file.each do |line|
      count += 1
      split_col_data = line.gsub('"', '').split(@delimiter)[@split_column_number]
      @data[split_col_data] = [] unless @data.key?(split_col_data)
      @data[split_col_data].push(line)
    end
    logger.info "Downloaded #{count} lines"
  end

  def save_files
    @data.each do |key, lines|
      if key.nil?
        logger.info "Error: nil key, skipping save"
        next
      end
      filename = new_filename(key)
      logger.info "Saving #{filename}"
      File.open(filename, 'w') do |f|
        f.write(@original_header)
        lines.each do |line|
          f.write(line)
        end
      end
    end
  end

  def new_filename(key)
    @destination_directory + '\meter-amr-readings-' + sprintf('%.0f', key) + '.csv'
  end

  def data_statistics
    @data.each do |key, lines|
      logger.info "#{key} #{lines.length}"
    end
  end
end

class ReconcileMeters
  NOSCHOOL = 'no school'
  attr_reader :school_map
  def initialize(data, school_metadata, school_name_filter = nil)
    @data = data
    @school_metadata = school_metadata
    @school_name_filter = school_name_filter
  end

  def school(mpan_mprn)
    @school_metadata.school(mpan_mprn, :mpan_mprn)
  end

  def reconcile
    @school_map = {}
    @data.each_key do |mpan_mprn|
      school = school(mpan_mprn)
      school_name = school.nil? ? NOSCHOOL : school.name
      next if !@school_name_filter.nil? && @school_name_filter != school.name
      (@school_map[school_name] ||= []).push(mpan_mprn)
    end
  end

  def show_meters(missing_only = false)
    if missing_only
      logger.info 'Meters Not Associated with Schools'
      @school_map[NOSCHOOL].each do |mpan_mprn|
        logger.info "    #{mpan_mprn}"
      end
    else
      @school_map.sort.each do |school_name, meter_list|
        logger.info sprintf('%-32.32s: ', school_name) + meter_list.map{ |mpan_mprn| sprintf('%.0f', mpan_mprn) }.join(' ')
      end
    end
  end

  def emit_yml_for_missing_meters
    logger.info 'YAML Segments for Missing Meters:'
    meters = []
    @school_map[NOSCHOOL].each do |mpan_mprn|
      meters.push(meter_obj(mpan_mprn))
    end
    logger.info YAML.dump(meters)
    logger.info "#{meters.length} missing meters"
  end

  class YamlMeterSegment
    attr_reader :meter
    def initialize(mpan_mprn, meter_type, name = 'Unknown Primary School')
      @meter = meter_type == :electricity ? { mpan: mpan_mprn } : { mprn: mpan_mprn }
      @meter.merge!(
        { 
          meter_type: meter_type,
          name: name + (meter_type == :electricity ? ' Electricity Supply' : ' Gas Supply')
        }
        )
    end
  end

  def meter_obj(mpan)
    meter = YamlMeterSegment.new(mpan.to_s, mpan.to_s.length > 8 ? :electricity : :gas)
  end
end

@source_csv_filename = './MeterReadings/Front End CSV Downloads/all-amr-validated-readings.csv'
@destination_directory = './MeterReadings/Front End CSV Downloads/'
@save = false
@run_report = false
@school_filter = nil

def parse_command_line
  extend Logging
  args = ARGV.clone
  while !args.empty?
    if args[0] == '-source' && args.length >= 2
      @source_csv_filename = args[1]
      args.shift(2)
    elsif args[0] == '-destination' && args.length >= 2
      @destination_directory = args[1]
      args.shift(2)
    elsif args[0] == '-school' && args.length >= 2
      @school_filter = args[1]
      args.shift(2)
    elsif args[0] == '-removesubstitutedata' && args.length >= 1
      logger.info "Not implemented yet"
      exit
    elsif args[0] == '-save' && args.length >= 1
      @save = true
      args.shift(1)
    elsif args[0] == '-reports' && args.length >= 1
      @run_report = true
      args.shift(1)
    else
      logger.info 'Arguments -source <source csv filename> && -destination <destination directory> || -removesubstitutedata || -save || -reports || -school <school name>'
      logger.info "e.g. ruby script\split_amr_data_from_frontend_bulk_export.rb -source #{@source_csv_filename} -destination #{@destination_directory}"
      logger.info "provided arguments #{args}"
      exit
    end
  end
end

def save_to_local_analytics_marshal_and_yml_files(meter_collection)
  readings_db = LocalAnalyticsMeterReadingDB.new(meter_collection)
  readings_db.save_meter_readings
end

def report_results(reports, school_name, meter_collection)
  reports.setup_school(meter_collection, school_name)
  reports.excel_name = school_name

  reports.do_all_standard_pages_for_school

  reports.excel_name = school_name + ' bulk upload '
  reports.save_excel_and_html

  reports
end

def remove_corrected_meter_readings_from_meter_collection(meter_collection)
  logger.info "Removing already corrected meter readings from #{meter_collection.name}"
  meter_collection.all_meters.each do |meter|
    remove_corrected_meter_readings(meter)
  end
end

def remove_corrected_meter_readings(meter)
  logger.info "    Removing corrected meter readings from #{meter.mpan_mprn} #{meter.name} #{meter.fuel_type}"
  stats = {}
  stats.default = 0
  scalings = nil
  meter.amr_data.each do |date, one_days_reading|
    stats[one_days_reading.type] += 1
    if one_days_reading.type != 'ORIG'
      if one_days_reading.type == 'S31M' # reverse scaling
        scalings = meter.attributes(:meter_corrections).select { |correction| correction.key?(:rescale_amr_data) } if scalings.nil?
        scalings.each do |scaling|
          scale = scaling[:rescale_amr_data]
          if date >= scale[:start_date] && date <= scale[:end_date]
            one_days_reading.set_type('ORIG')
            new_amr_data = OneDayAMRReading.scale(one_days_reading, 1.0 / scale[:scale])
            meter.amr_data.add(date, new_amr_data)
          end
        end
      else
        meter.amr_data.delete(date) # delete non-ORIG data
      end
    end
  end
end

def compare_two_meter_collections(local_analystics_meter_collection, external_download_meter_collection)
  reconciler = MeterCollectionReconciler.new(local_analystics_meter_collection, external_download_meter_collection)
  reconciler.compare
  reconciler.print_comparison(3)
  reconciler.meters_with_percent_change_above(0.05)
end

def save_schools(school_map, school_metadata)
  reports = ReportConfigSupport.new

  school_map.each do |school_name, meters|
    logger.info '#' * 100
    logger.info "Saving #{school_name} , #{meters}"
    logger.info "\n" * 3
    meter_collection = school_metadata.school(school_name)

    load_meter_readings(meter_collection)

    save_to_local_analytics_marshal_and_yml_files(meter_collection) if @save

    report_results(reports, school_name, meter_collection) if @run_report
  end

  reports.report_benchmarks

  reports.report_failed_charts
end

def load_meter_readings(meter_collection, validate = true, aggregate = true)
  downloader = MeterReadingsDownloadBase::meter_reading_factory(:downloadfromfrontend, meter_collection)
  downloader.load_meter_readings

  meter_collection.all_meters.each do |meter|
    meter.amr_data.set_long_gap_boundary
  end

  AggregateDataService.new(meter_collection).validate_meter_data if validate
  AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters if aggregate
end

def compare_school_meter_readings(school_metadata1, school_metadata2, school_name)
  school1 = school_metadata1.school(school_name, :name)
  load_meter_readings(school1, false, false)
  school2 = school_metadata2.school(school_name, :name)
  load_meter_readings(school2, false, false)
  remove_corrected_meter_readings_from_meter_collection(school2)
  AggregateDataService.new(school2).validate_meter_data

  meters_to_check = compare_two_meter_collections(school1, school2)
  save_to_local_analytics_marshal_and_yml_files(school2)
  meters_to_check
end

parse_command_line

missing_schools = [
  'Average School',
  'Hayesdown First School',
  'Hunters Bar School',
  'Lowfields Primary School',
  'Meersbrook Primary School',
  'Mundella Primary School',
  'Oakfield School',
  'Phillimore School',
  'Selwood Academy',
  'Shortbrook School',
  'St Johns First School',
  'Valley Park School',
  'Vallis First School'
]
school_metadata1 = AnalysticsSchoolAndMeterMetaData.new
school_metadata2 = AnalysticsSchoolAndMeterMetaData.new

problematic_meters = {}
school_metadata1.meter_collections.each do |school_name, _school|
  next if missing_schools.include?(school_name)
  # next if school_name != 'Saltford C of E Primary School'
  logger.info '&' * 100
  logger.info '&' * 100
  logger.info '&' * 100
  puts '&' * 100
  puts "Doing #{school_name}"
  # Logging.logger.reopen('log/QQ bulk-amr-upload ' + school_name + ' ' + Time.now.strftime('%H %M') + '.log')
  meters_to_check = compare_school_meter_readings(school_metadata1, school_metadata2, school_name)
  problematic_meters[school_name] = meters_to_check unless meters_to_check.empty?
  puts "\n" * 5, "Problem at #{school_name}" unless meters_to_check.empty?
end

puts 'Problematic Meters'

problematic_meters.each do |school_name, problem_meters|
  problem_meters.each do |meter_id, meter_reconcile|
    puts "#{school_name} #{meter_id} #{(meter_reconcile.percent * 100.0).round(1)}"
  end
end

exit
logger.info "\n" * 10

school_metadata2 = AnalysticsSchoolAndMeterMetaData.new

splitter = CSVSplitter.new(@source_csv_filename, @destination_directory, 'Mpan Mprn', ',')

splitter.split

reconcile = ReconcileMeters.new(splitter.data, school_metadata, @school_filter)

reconcile.reconcile

reconcile.show_meters

save_schools(reconcile.school_map, school_metadata) if @save

# reconcile.emit_yml_for_missing_meters
