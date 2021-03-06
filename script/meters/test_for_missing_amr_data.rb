# standlone program for loading and then checking for
# missing amr data
require 'require_all'
require_relative '../lib/dashboard.rb'
require_all 'test_support'

module Logging
  @logger = Logger.new('log/test-for-missing-amr-data.log')
  logger.level = :warn
end

list_of_schools = [
  'Bishop Sutton Primary School',
  'Castle Primary School',
  'Freshford C of E Primary',
  'Marksbury C of E Primary School',
  'Paulton Junior School',
  'Pensford Primary',
  'Roundhill School',
  'Saltford C of E Primary School',
  'St Johns Primary',
  'Stanton Drew Primary School',
  'Twerton Infant School',
  'Westfield Primary'
]

def summarise_missing_dates(missing_dates)
  consolidated_dates = []
  period_start_date = missing_dates[0]
# logger.debug "Processing #{missing_dates.length}"
  for i in 0..missing_dates.length - 1 do
    date = missing_dates[i]
    if i == missing_dates.length || date + 1 != missing_dates[i + 1]
      consolidated_dates.push([period_start_date, date])
      # logger.debug "pushing #{period_start_date} and #{date}"
      period_start_date = missing_dates[i + 1] unless i == missing_dates.length
    end
  end
# logger.debug "Got #{consolidated_dates.length} ranges"
  consolidated_dates.each do |missing_date_range|
    if missing_date_range[0] == missing_date_range[1]
      Logging.logger.debug "Bullet #{missing_date_range[0]}"
    else
      days = (missing_date_range[1] - missing_date_range[0] + 1).to_i
      Logging.logger.debug "Bullet #{missing_date_range[0]} to #{missing_date_range[1]} (x #{days})"
    end
  end
end

def list_missing_amr_data(school_name, meter)
  missing_date_count = 0
  missing_dates = []
  amr_data = meter.amr_data
  # Logging.logger.debug "processing data from  #{amr_data.start_date}  to #{amr_data.end_date}"
  (amr_data.start_date..amr_data.end_date).each do |date|
    missing_dates.push(date) if amr_data.date_missing?(date)
  end
  days_data = (amr_data.end_date - amr_data.start_date + 1).to_i # force  integer not rational
  Logging.logger.debug "#{school_name}: #{meter.meter_type} #{meter.id} processing data from  #{amr_data.start_date}  to #{amr_data.end_date} #{days_data} days data #{missing_dates.length} missing"
  summarise_missing_dates(missing_dates) if missing_dates.length > 0
end

ENV['CACHED_METER_READINGS_DIRECTORY'] = './MeterReadings/'

$SCHOOL_FACTORY = SchoolFactory.new

list_of_schools.each do |school_name|
  Logging.logger.debug school_name
  meter_collection = $SCHOOL_FACTORY.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)
  Logging.logger.debug meter_collection.methods.grep(/ete/)
  meter_collection.heat_meters.each do |heat_meter|
    # logger.debug "Got #{heat_meter.meter_type} #{heat_meter.id}"
    list_missing_amr_data(school_name, heat_meter)
  end
  meter_collection.electricity_meters.each do |electricity_meter|
    # logger.debug "Got #{electricity_meter.meter_type} #{electricity_meter.id}"
    list_missing_amr_data(school_name,electricity_meter)
  end
end
