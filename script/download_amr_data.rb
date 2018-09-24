# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  # @logger = Logger.new('Results/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
  # @logger.level = :debug
end

def download_and_compare_school_from_socrata_and_locally
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

  # reports.do_chart_list('Boiler Control', [:optimum_start])

  reports.do_all_standard_pages_for_school

  reports.save_excel_and_html

  reports.report_benchmarks
end

def load_bath_csv
  school_name = 'St Saviours Junior'
  postcode = 'BA1 6RB'

  school_metadata = AnalysticsSchoolAndMeterMetaData.new

  meter_collection_csv = school_metadata.school(school_name)

  csv_download = LoadSchoolFromBathSplitCSVFile.new(meter_collection_csv, school_name, postcode)

  csv_download.load_data
end

def load_frome_amr(school_name = 'Trinity First School')
  school_metadata = AnalysticsSchoolAndMeterMetaData.new

  meter_collection_files = school_metadata.school(school_name)

  csv_xlsx_downloads = LoadSchoolFromFromeFiles.new(meter_collection_files, school_name)

  csv_xlsx_downloads.load_data

  meter_collection_files
end

school_name = 'Trinity First School'

meter_collection = load_frome_amr(school_name)

report_results(school_name, meter_collection)

