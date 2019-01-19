# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new(STDOUT)
end

locations = {
  'Bath'      => [51.39, -2.37],
  'Sheffield' => [53.3811, -1.4701],
  'Frome'     => [51.2308, -2.3201],
  'Bristol'   => [51.4545, -2.5879]
}

nearest_weather_station = MetOfficeDatapointWeatherForecast.find_nearest_weather_station(51.39, -2.37)

forecast = MetOfficeDatapointWeatherForecast.new(nearest_weather_station['id'].to_i)
# puts forecast.forecast

locations.each do |name, latitude_longitude|
  Logging.logger.info '=' * 80
  Logging.logger.info "Downloading met office weather forecast for #{name}"
  Logging.logger.info ''

  nearest_weather_station = MetOfficeDatapointWeatherForecast.find_nearest_weather_station(latitude_longitude[0], latitude_longitude[1])
  forecast = MetOfficeDatapointWeatherForecast.new(nearest_weather_station['id'].to_i)
  Logging.logger.info nearest_weather_station['id']
  forecast.forecast.each do |date, forecast_temperatures|
    Logging.logger.info "    #{date} = #{forecast_temperatures}"
  end
end
