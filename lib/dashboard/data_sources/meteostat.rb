# Interface to Meteostat weather data
#
# documentation: https://dev.meteostat.net/api/point/hourly.html
#
# - Daily limit of 2,000 queries per day, no paid option above that
# - JSON limited to 10 days historic hourly data at a time
# - so 20,000 days capacity per day => 60 location years
# - status 429 errors - too frequent querying occur regularly on bulk
# - downloads, interface below gradually throttles and retries if this happens
# - suggest downloading 8 days of data when querying most recent data in front end
# - the interface below interpolates for missing data and the half hour points
# - interface requires an altitude, currently defaulted to 30m
# - data seems to go back before 2008
# - you will need to set environment variable: ENERGYSPARKSMETEOSTATAPIKEY
require 'net/http'
require 'json'
require 'date'
require 'time'
require 'amazing_print'
require 'faraday'
require 'faraday_middleware'
require 'interpolate'
require 'tzinfo'

class MeteoStat
  def initialize(api_key = ENV['ENERGYSPARKSMETEOSTATAPIKEY'])
    @api_key = api_key
    @schools_timezone = TZInfo::Timezone.get('Europe/London')
  end

  # returns a hash, with 2 entries
  # - [:temperatures] => { Date => [ float x 48 ]
  # - [:missing]      => [ Time ]
  def historic_temperatures(latitude, longitude, start_date, end_date, altitude = 30.0)
    raw_data = download(latitude, longitude, start_date, end_date, altitude)
    convert_to_datetime_to_x48(raw_data, start_date, end_date)
  end

  def nearest_weather_stations(latitude, longitude, number_of_results = 8, within_radius_km = 100)
    download_nearby_stations(latitude, longitude, number_of_results, within_radius_km)
  end

  private

  def download(latitude, longitude, start_date, end_date, altitude)
    datetime_to_temperature = []
    (start_date..end_date).to_a.each_slice(10).each do |dates|
      raw_data = download_10_days_data(latitude, longitude, dates.first, dates.last, altitude)
      datetime_to_temperature += raw_data['data'].map{ |reading| parse_temperature_reading(reading) }
    end
    datetime_to_temperature.to_h
  end

  def convert_to_datetime_to_x48(temperatures, start_date, end_date)
    interpolator = Interpolate::Points.new(convert_weather_data_for_interpolation(temperatures))
    dated_temperatures = {}
    missing = []
    (start_date..end_date).each do |date|
      dated_temperatures[date] = []
      (0..23).each do |hour|
        dt = Time.new(date.year, date.month, date.day, hour, 0, 0)
        missing.push(dt) unless temperatures.key?(dt) && time_exists?(dt)
        [0, 30].each do |halfhour|
          t = Time.new(date.year, date.month, date.day, hour, halfhour, 0)
          dated_temperatures[date].push(interpolator.at(t.to_i).round(2))
        end
      end
    end
    {temperatures: dated_temperatures, missing: missing}
  end

  # get missing data for March/Spring clocks going forward
  # at 1pm, test for and don't add to missing data
  #
  # this interface currently doesn't work - seems Meteostat
  # and TZInfo disagree slightly on when the clocks go forward
  def time_exists?(datetime)
    begin
      @schools_timezone.utc_to_local(datetime)
      true
    rescue TZInfo::PeriodNotFound => _e
      false
    end
  end

  def convert_weather_data_for_interpolation(temperatures)
    temperatures.transform_keys{ |time| time.to_i}
  end

  def download_10_days_data(latitude, longitude, start_date, end_date, altitude)
    url = historic_temperatures_url(latitude, longitude, start_date, end_date, altitude)
    json_request(url)
  end

  def download_nearby_stations(latitude, longitude, number_of_results, within_radius_km)
    json = download_nearby_stations_json_request(latitude, longitude, number_of_results, within_radius_km)
  end

  def download_nearby_stations_json_request(latitude, longitude, number_of_results, within_radius_km)
    url = nearby_stations_url(latitude, longitude, number_of_results, within_radius_km)
    station_list = json_request(url)['data']
    station_list.map do |station_details|
      raw_station_data = find_station(station_details['id'])
      extract_station_data(raw_station_data['data'][0], station_details)
    end
  end

  def extract_station_data(data, station_details)
    {
      name:       data['name']['en'],
      latitude:   data['latitude'],
      longitude:  data['longitude'],
      elevation:  data['elevation'],
      distance:   station_details['distance']
    }
  end

  def find_station(identifier)
    @cached_stations ||= {}
    @cached_stations[identifier] ||= download_station(identifier)
  end

  def download_station(identifier)
    url = find_station_url(identifier)
    json_request(url)
  end

  def json_request(url)
    # there seem to be status 429 failures - if you make too
    # many requests in too short a time
    back_off_sleep_times = [0.1, 0.2, 0.5, 1.0, 5.0]
    connection = Faraday.new(url, headers: authorization)
    response = nil
    back_off_sleep_times.each do |time_seconds|
      response = connection.get
      break if response.status == 200
      sleep time_seconds
    end
    raise StandardError, "Timed out after #{back_off_sleep_times.length} attempts" if response.status != 200

    JSON.parse(response.body)
  end

  def authorization
    { 'x-api-key' => @api_key }
  end

  def url_date(date)
    date.strftime('%Y-%m-%d')
  end

  def historic_temperatures_url(latitude, longitude, start_date, end_date, altitude)
    'https://api.meteostat.net/v2/point/hourly' +
    '?lat='     + latitude.to_s +
    '&lon='     + longitude.to_s +
    '&alt='     + altitude.to_i.to_s +
    '&start='   + url_date(start_date) +
    '&end='     + url_date(end_date) +
    '&tz=Europe/London'
  end

  def nearby_stations_url(latitude, longitude, number_of_results, within_radius_km)
    'https://api.meteostat.net/v2/stations/nearby' +
    '?lat='     + latitude.to_s +
    '&lon='     + longitude.to_s +
    '&limit='   + number_of_results.to_i.to_s +
    '&radius='  + within_radius_km.to_i.to_s
  end

  def find_station_url(identifier)
    "https://api.meteostat.net/v2/stations/search?query=#{identifier}"
  end

  def parse_temperature_reading(reading)
    [
      Time.parse(reading['time_local']),
      reading['temp'].to_f
    ]
  end
end
