require 'net/http'
require 'json'
require 'date'
require 'awesome_print'

# 5 day forecast appears to be free, longer forecast appear to be on a different tier
class AccuWeatherForecast
  include Logging
  attr_reader :forecast

  @@api_key = nil

  def initialize(weather_station_id)
    download_forecast(weather_station_id)
  end

  # Bath = 326920, Frome = 325651, Sheffield = 326914, Bristol = 327328
  def self.find_nearest_weather_station(latitude, longitude)
    url = 'http://dataservice.accuweather.com/locations/v1/cities/geoposition/search?q=' + latitude.to_s + ',' + longitude.to_s  + '&apikey=' + key
    uri = URI(url)
    response = Net::HTTP.get(uri)
    nearest_city = JSON.parse(response)
    [nearest_city['Key'], nearest_city['EnglishName']]
  end

  public

  def download_forecast(weather_station_id)
    Logging.logger.info 'Downloading forecast from accu weather for #{weather_station_id}'
    @forecast = {}
    url = 'http://dataservice.accuweather.com/forecasts/v1/daily/5day/' + weather_station_id.to_s + '?apikey=' + self.class.key
    uri = URI(url)
    response = Net::HTTP.get(uri)

    forecast_data = JSON.parse(response)

    forecast_data['DailyForecasts'].each do |forecast|
      date = Date.parse(forecast['Date'])

      min_temperature_f = forecast['Temperature']['Minimum']['Value']
      max_temperature_f = forecast['Temperature']['Maximum']['Value']
      avg_temperature_f = (min_temperature_f + max_temperature_f) / 2.0

      min_temperature_c = temp_to_c(min_temperature_f)
      avg_temperature_c = self.temp_to_c(avg_temperature_f)
      max_temperature_c = self.temp_to_c(max_temperature_f)

      @forecast[date] = [min_temperature_c, avg_temperature_c, max_temperature_c]
    end

    logger.info "Downloaded accu weather for station id #{weather_station_id}"
    logger.info "Forecast: #{@forecast}"
    logger.info "URL: #{url}"
  end

  public

  def temp_to_c(f)
    ((f - 32.0) * 5.0 / 9.0).round(1)
  end

  def self.key
    @@api_key = ENV['ENERGYSPARKSACCUWEATHERAPIKEY'] if @@api_key.nil?
    raise EnergySparksUnexpectedStateException.new('Missing ENERGYSPARKSACCUWEATHERAPIKEY enviroment variable') if @@api_key.nil?
    @@api_key
  end
end