require 'awesome_print'
require 'digest'
require 'net/http'
require 'json'
require 'uri'
require 'tzinfo'
require 'open-uri'
# Test programme to understand Hildebrand Glo API
#
# you need to set environment variables HILDEBRAND_USER_ID and HILDEBRAND_APP_KEY for this to work
#
# Working command:
#
# curl -X GET
#      -H "userId: 431d3211-9ad5-4bbf-be78-73888c59027e"
#      -H "Authorization: Basic HILDEBRAND_APP_KEY"
#         "https://api.glowmarkt.com/api/v0-1/resource/f4c88949-73b3-49ae-8112-60e3e7ce65de/readings?from=2019-06-01T00:00:00&to=2019-06-10T23:59:59&period=PT30M&oﬀset=-60&function=sum"
# or
# curl  --location
#       --request GET 'https://api.glowmarkt.com/api/v0-1/resource/c0013a52-6a15-492c-bcab-38aeaa483386/readings?from=2020-01-01T00:00:00&to=2020-03-31T23:59:59&period=P1M&offset=-60&function=sum'
#       --header 'userId: HILDEBRAND_USER_ID'
#       --header 'Authorization: Basic HILDEBRAND_APP_KEY'
GET_READINGS_URL = 'https://api.glowmarkt.com/api/v0-1/resource/'
EXAMPLE_METER_RESOURCE = 'c0013a52-6a15-492c-bcab-38aeaa483386'
JSON_QUERY = '/readings?from=2019-06-01T00:00:00&to=2019-06-10T23:59:59&period=PT30M&oﬀset=-60&function=sum'

require 'faraday'

class HildebrandGlo
  def initialize
  end

  def meter_readings(start_date, end_date)
    readings = {}
    (start_date..end_date).each_slice(10) do |date_range_max_10days|
      readings.merge!(meter_readings_10_day_chunk(date_range_max_10days.first, date_range_max_10days.last))
    end
    puts "Total kwh = #{readings.values.map(&:sum).sum}"
  end

  def meter_readings_10_day_chunk(start_date, end_date)
    readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour kwh]

    kwhs = {}
    raw_data = json_query(start_date, end_date)
    raw_data['data'].each do |reading|
      date, half_hour_index = parse_hildebrand_datetime_to_date_and_half_hour_index(hildebrand_time_parse(reading[0]))
      readings[date][half_hour_index] += reading[1].to_f # TODO(PH, 24May2020) really need to check to nil before .to_f
    end
    
    readings
  end

  def parse_hildebrand_datetime_to_date_and_half_hour_index(dt)
    date = dt.to_date
    half_hour_index = ((dt - date) * 48).to_i
    [date, half_hour_index]
  end

  def json_query(start_date, end_date)
    url = GET_READINGS_URL + EXAMPLE_METER_RESOURCE + json_meter_reading_query(start_date, end_date)
    # puts url
    uri = URI.parse(URI.escape(url))
    connection = Faraday.new(uri, headers: { 'userId' => ENV['HILDEBRAND_USER_ID'], 'Authorization' => 'Basic ' + ENV['HILDEBRAND_APP_KEY']})
    response = connection.get
    JSON.parse(response.body)
  end

  def json_meter_reading_query(start_date, end_date)
    '/readings?from=' + url_date(start_date) + '&to=' + url_date(end_date, true) + '&period=PT30M&oﬀset=-60&function=sum'
  end

  def url_date(date, end_date = false)
    end_date ? date.strftime('%Y-%m-%dT23:59:59') : date.strftime('%Y-%m-%dT00:00:00') 
  end

  def hildebrand_time_parse(seconds_since_1_jan_1970)
    DateTime.new(1970, 1, 1, 0, 0, 0) + (seconds_since_1_jan_1970 / (24.0 * 60.0 * 60.0))
  end
end

HildebrandGlo.new.meter_readings(Date.new(2018, 1, 1), Date.new(2020, 5, 10))
