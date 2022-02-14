# Bath:Hacked Soctrata Electricity and Gas download
#
# electricity data is an array of:
#             "_00_30" => "29.3"
#       ......
#             "_24_00" => "29.3",
#             "date" => "2009-08-10T00:00:00.000",
#             "id" => "a299b2e68dcd7c4c16612d81569f289f",
#             "location" => "Guildhall Electricity Supply 1 (HH)",
#             "mpan" => "2200030370866", || mprn for gas data
#             "msid" => "K05D01635",
#             "postcode" => "BA1 5AW",
#             "totalunits" => "1841.6",
#             "units" => "kWh"
#
# caches results as YAML in local directory ENV["CACHED_METER_READINGS_DIRECTORY"]
# you need to delete files in this directory of you want updated data
# download currently limited to 2000 rows (~6years) to limit impact on Socrata
#
require 'net/http'
require 'json'
require 'date'
require 'soda'
require 'soda/client'
require 'yaml'
require 'benchmark'
require 'pry-byebug'
require_relative '../app/services/aggregation_service.rb'
require_relative '../app/models/meter_collection.rb'
require_relative './meterreadings_download_baseclass.rb'

def meter_number_column(type)
  type == 'electricity' ? 'mpan' : 'mprn'
end

class BathHackedSocrataDownload < MeterReadingsDownloadBase
  include Logging

  attr_accessor :min_date

  def initialize(meter_collection)
    super(meter_collection)
    @min_date = Date.new(2008, 9, 1)

    ENV['SOCRATA_STORE'] = 'data.bathhacked.org'
    ENV['SOCRATA_TOKEN'] = 'gQ5Dw0rIF7I8ij40m8W6ulHj4'
    ENV['SOCRATA_LIMIT'] = '4000'
    @client = SODA::Client.new(domain: ENV['SOCRATA_STORE'], app_token: ENV['SOCRATA_TOKEN'])

    @halfhours = %w(
      _00_30 _01_00 _01_30 _02_00 _02_30 _03_00 _03_30 _04_00
      _04_30 _05_00 _05_30 _06_00 _06_30 _07_00 _07_30 _08_00
      _08_30 _09_00 _09_30 _10_00 _10_30 _11_00 _11_30 _12_00
      _12_30 _13_00 _13_30 _14_00 _14_30 _15_00 _15_30 _16_00
      _16_30 _17_00 _17_30 _18_00 _18_30 _19_00 _19_30 _20_00
      _20_30 _21_00 _21_30 _22_00 _22_30 _23_00 _23_30 _24_00
    )
  end

  def load_meter_readings
    logger.info "Downloading meter readings from Bath Hacked/Socrata for #{@meter_collection.name} from #{@min_date}"
    (@meter_collection.heat_meters + @meter_collection.electricity_meters).each do |meter|
      meter.add_correction_rule({ auto_insert_missing_readings: { type: :weekends} }) if meter.meter_type == :gas
      meter_readings = download_meter_readings(meter.id, meter.fuel_type, @min_date)
      meter_readings.each do |meter_reading|
        meter.amr_data.add(meter_reading.date, meter_reading)
      end
      logger.info "Downloaded #{meter_readings.length} meter readings for meter #{meter.id} fuel type #{meter.fuel_type}"
    end
  end

  private

  def query(meter_id, type, since_date = nil)
    column = type == :electricity ? 'mpan' : 'mprn'

    where = '(' + "#{column}='#{meter_id}'" + ')'

    where << " AND date >='#{since_date.iso8601}'" if since_date
    {
        '$where' => where,
        '$order' => 'date ASC',
        '$limit' => ENV['SOCRATA_LIMIT']
    }
  end

  def download_meter_readings(identifier, meter_type, min_date)
    meter_readings = []
    query = query(identifier, meter_type, min_date)
    table = meter_type == :electricity ? 'fqa5-b8ri' : 'rd4k-3gss'
    @client.get(table, query).each do |days_data|
      date = Date.parse(days_data['date'])
      readings = []
      @halfhours.each do |date_col_identifier|
        readings.push(days_data[date_col_identifier].to_f)
      end
      one_days_data = OneDayAMRReading.new(identifier, date, 'ORIG', nil, DateTime.now, readings)
      meter_readings.push(one_days_data)
    end
    meter_readings
  end
end
