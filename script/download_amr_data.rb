# Downloads data from various sources into local meterreadings marshal binary database
# for subsequent reuse by analytics dashboard etc. testing code
# also used for testing new (Sep 2018) amr_one_days_data.rb and meter_collection comparison functionality
# Usage: ruby download_amr_data.rb -allschools || -school <school name> || -reports
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require './test_support/meterreadings_download_baseclass.rb'

@school_download_list = []
@run_report = false
@save = false

module Logging
  @logger = Logger.new('log/test-amr-data_load ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = Logger::DEBUG
end

@school_data_sources = {
  'Bishop Sutton Primary School'      => :bathhacked,
  'Castle Primary School'             => :bathcsv,
  'Freshford C of E Primary'          => :bathhacked,
  'Marksbury C of E Primary School'   => :bathhacked,
  'Paulton Junior School'             => :bathhacked,
  'Pensford Primary'                  => :bathhacked,
  'Roundhill School'                  => :bathhacked,
  'Saltford C of E Primary School'    => :bathhacked,
  'St Marks Secondary'                => :bathhacked, # :bathcsv,
  'St Johns Primary'                  => :bathhacked,
  'St Saviours Junior'                => :bathhacked,
  'Stanton Drew Primary School'       => :bathhacked,
  'Twerton Infant School'             => :bathhacked,
  'Westfield Primary'                 => :bathhacked,
  'Bankwood Primary School'           => :sheffieldcsv,
  'Ecclesall Primary School'          => :sheffieldcsv,
  'Ecclesfield Primary School'        => :sheffieldcsv,
  'Hunters Bar School'                => :sheffieldcsv,
  'Lowfields Primary School'          => :sheffieldcsv,
  'Meersbrook Primary School'         => :sheffieldcsv,
  'Mundella Primary School'           => :sheffieldcsv,
  'Phillimore School'                 => :sheffieldcsv,
  'Shortbrook School'                 => :sheffieldcsv,
  'Valley Park School'                => :sheffieldcsv,
  'Walkley School Tennyson School'    => :sheffieldcsv,
  'Whiteways Primary'                 => :sheffieldcsv,
  'Woodthorpe Primary School'         => :sheffieldcsv,
  'Wybourn Primary School'            => :sheffieldcsv,
  'Christchurch First School'         => :fromecsv,
  'Frome College'                     => :fromecsv,
  'Critchill School'                  => :fromecsv,
  'Hayesdown First School'            => :fromecsv,
  'Oakfield School'                   => :fromecsv,
  'Selwood Academy'                   => :fromecsv,
  'St Johns First School'             => :fromecsv,
  'St Louis First School'             => :fromecsv,
  'Trinity First School'              => :fromecsv,
  'Vallis First School'               => :fromecsv
}

def parse_command_line
  extend Logging
  args = ARGV.clone
  while !args.empty?
    if args[0] == '-allschools'
      @school_download_list = @school_data_sources.keys
      args.shift(1)
    elsif args[0] == '-reports'
      @run_report = true
      args.shift(1)
    elsif args[0] == '-save'
      @save = true
      args.shift(1)
    elsif args[0] == '-logtofile'
      puts 'Using log file for debug output'
      @logger =  Logger.new('log/test-amr-data_load ' + Time.now.strftime('%H %M') + '.log') # doesn't work, ask James?
      @logger.level = Logger::DEBUG
      args.shift(1) 
    elsif args[0] == '-school' && args.length >= 2
      if @school_data_sources.key?(args[1])
        @school_download_list = [args[1]]
      else
        @logger.error "-school #{args[1]} specified school not on download list"
        school_list_str = @school_data_sources.keys..join("', '")
        @logger.info "Choice of schools: #{school_list_str}"
      end
      args.shift(2)
    else
      puts 'Arguments -allschools || -school <school name> || -reports || -logtofile'
      puts "provided arguments #{args}"
      exit
    end
  end
end

def download_and_compare_school_from_socrata_and_locally_deprecated
  school_name = 'St Marks Secondary'

  school_metadata = AnalysticsSchoolAndMeterMetaData.new
  meter_collection_local = school_metadata.school(school_name)

  meter_collection_external = Marshal.load(Marshal.dump(meter_collection_local))

  readings_db = LocalAnalyticsMeterReadingDB.new(meter_collection_local)
  readings_db.load_meter_readings

  readings = BathHackedSocrataDownload.new(meter_collection_external)
  readings.load_meter_readings
  AggregateDataService.new(meter_collection_external).validate_and_aggregate_meter_data

  collection_manager = MeterCollectionManager.new(meter_collection_local, meter_collection_external)
  collection_manager.compare
end

def report_results(school_name, meter_collection)
  reports = ReportConfigSupport.new

  reports.setup_school(meter_collection, school_name)

  reports.do_all_standard_pages_for_school

  reports.save_excel_and_html

  reports.report_benchmarks
end

def compare_two_meter_collections(local_analystics_meter_collection, external_download_meter_collection)
  collection_manager = MeterCollectionManager.new(local_analystics_meter_collection, external_download_meter_collection)
  collection_manager.compare
end

def download_from_local_analytics_marshal_file(school_name)
  meter_collection = @school_metadata.school(school_name)

  readings_db = LocalAnalyticsMeterReadingDB.new(meter_collection)

  readings_db.load_meter_readings

  meter_collection
end

def save_to_local_analytics_marshal_and_yml_files(meter_collection)
  readings_db = LocalAnalyticsMeterReadingDB.new(meter_collection)
  readings_db.save_meter_readings
end

def process_selected_schools
  @school_download_list.each do |school_name|
    # meter_collection = download_school(school_name)

    meter_collection = @school_metadata.school(school_name)

    puts "Downloading #{school_name}"

    downloader = MeterReadingsDownloadBase::meter_reading_factory(@school_data_sources[school_name], meter_collection)
    downloader.load_meter_readings

    AggregateDataService.new(meter_collection).validate_and_aggregate_meter_data

    save_to_local_analytics_marshal_and_yml_files(meter_collection) if @save

    report_results(school_name, meter_collection) if @run_report
  end
end

# MAIN

parse_command_line

@school_metadata = AnalysticsSchoolAndMeterMetaData.new

process_selected_schools
