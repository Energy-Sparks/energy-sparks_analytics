require 'net/http'
require 'json'
require 'date'
require 'awesome_print'
# required Energy Sparks API key needs setting in ENERGYSPARKSMETOFFICEDATAPOINTAPIKEY environment variable
# choice of sites: http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/xml/sitelist?key=
# 5 day x 3 hour forecast: http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/xml/3840?res=3hourly&key=
#
# Usage:
#   nearest_weather_station = MetOfficeDatapointWeatherForecast.find_nearest_weather_station(51.39, -2.37)
#
#   forecast = MetOfficeDatapointWeatherForecast.new(nearest_weather_station['id'])
#   puts forecast.forecast.inspect
#
class MetOfficeDatapointWeatherForecast
  include Logging

  @@api_key = nil
  @@weather_station_site_data = nil
  attr_reader :forecast

  def initialize(weather_station)
    download_forecast(weather_station)
  end

  public

  def self.find_nearest_weather_station(latitude, longitude)
    sites = weather_station_sites
    sites_by_distance = {}
    sites.each do |site|
      distance_km = 111 * ((site['latitude'].to_f - latitude)**2 + (site['longitude'].to_f - longitude)**2)**0.5
      sites_by_distance[distance_km] = site
    end
    nearest_distance = sites_by_distance.keys.min
    nearest = sites_by_distance[nearest_distance]
    Logging.logger.info "Found nearest met office weather station for #{latitude}, #{longitude}"
    Logging.logger.info nearest
    nearest
  end

  private

  def download_forecast(weather_station_id)
    @forecast = {}
    url = 'http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/json/' + weather_station_id + '?res=3hourly&key=' + self.class.key
    uri = URI(url)
    response = Net::HTTP.get(uri)
    forecast_data = JSON.parse(response)
    day_forecasts = forecast_data['SiteRep']['DV']['Location']['Period']
    day_forecasts.each do |day_forecast|
      date, min_avg_max_temperature = process_day(day_forecast)
      @forecast[date] = min_avg_max_temperature
    end
    logger.info "Downloaded met office weather forecast for station id #{weather_station_id}"
    logger.info "Forecast: #{@forecast}"
    logger.info "URL: #{url}"
  end

  def process_day(day_forecast)
    date = Date.parse(day_forecast['value'])
    # .to_f seems superfluous given the temperatures appear to be integers!
    temperatures = day_forecast['Rep'].map { |reading| reading['T'].to_f }
    if temperatures.length <= 3 # if less than 3 x 3 hour readings, typically for the remainder of today, skip readings
      [nil, nil]
    else
      min_avg_max = [ 
        temperatures.min,
        temperatures.inject { |sum, el| sum + el } / temperatures.length, # avg
        temperatures.max
      ] 
      [date, min_avg_max]
    end
  end

  private_class_method def self.weather_station_sites
    if @@weather_station_site_data.nil?
      Logging.logger.info 'Making a request to the met office for a list of weather stations'
      url = 'http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/json/sitelist?key=' + key
      Logging.logger.info "URL for weather stations is #{url}"
      uri = URI(url)
      response = Net::HTTP.get(uri)
      locations_data = JSON.parse(response)
      @@weather_station_site_data = locations_data['Locations']['Location']
    end
    @@weather_station_site_data
  end

  public # TODO(PH, 8Jan2019) - would like to make this a private_class_method but Ruby doesn't seems to allow instance call

  def self.key
    @@api_key = ENV['ENERGYSPARKSMETOFFICEDATAPOINTAPIKEY'] if @@api_key.nil?
    raise EnergySparksUnexpectedStateException.new('Missing ENERGYSPARKSMETOFFICEDATAPOINTAPIKEY enviroment variable') if @@api_key.nil?
    @@api_key
  end
end