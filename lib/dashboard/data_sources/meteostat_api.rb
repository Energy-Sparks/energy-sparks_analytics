# Interface to Meteostat weather data
#
# documentation: https://dev.meteostat.net/api/point/hourly.html
#
require 'json'
require 'faraday'
require 'faraday_middleware'
require 'limiter'
require 'retriable'

class MeteoStatApi
  extend Limiter::Mixin

  limit_method :get, rate: 2, interval: 1

  class RateLimitError < StandardError; end
  class HttpError < StandardError; end

  def initialize(api_key)
    @api_key = api_key
  end

  def historic_temperatures(latitude, longitude, start_date, end_date, altitude)
    get(historic_temperatures_url(latitude, longitude, start_date, end_date, altitude))
  end

  def nearby_stations(latitude, longitude, number_of_results, within_radius_km)
    get(nearby_stations_url(latitude, longitude, number_of_results, within_radius_km))
  end

  def find_station(identifier)
    get(find_station_url(identifier))
  end

  private

  def historic_temperatures_url(latitude, longitude, start_date, end_date, altitude)
    # base_url +
      '/point/hourly' +
      '?lat='     + latitude.to_s +
      '&lon='     + longitude.to_s +
      '&alt='     + altitude.to_i.to_s +
      '&start='   + url_date(start_date) +
      '&end='     + url_date(end_date) +
      '&tz=Europe/London'
  end

  def nearby_stations_url(latitude, longitude, number_of_results, within_radius_km)
    # base_url +
      '/stations/nearby' +
      '?lat='     + latitude.to_s +
      '&lon='     + longitude.to_s +
      '&limit='   + number_of_results.to_i.to_s +
      '&radius='  + within_radius_km.to_i.to_s
  end

  def find_station_url(identifier)
    # base_url +
      '/stations/search' +
      "?query=#{identifier}"
  end

  def url_date(date)
    date.strftime('%Y-%m-%d')
  end

  def headers
    { 'x-api-key' => @api_key }
  end

  def base_url
    'https://api.meteostat.net/v2'
  end

  def get_client(url, headers)
    Faraday.new(url, headers: headers)
  end

  def get(url)

    client = get_client(base_url+url, headers)

    # 3 retries with randomised intervals around 0.5, 0.75, 1.125
    # https://github.com/kamui/retriable
    response = Retriable.retriable do
      ret = client.get
      raise RateLimitError, "Rate limited" if ret.status == 429
      ret
    end

    raise HttpError, "MeteoStatApi error" unless response.status == 200
    JSON.parse(response.body)
  end
end
