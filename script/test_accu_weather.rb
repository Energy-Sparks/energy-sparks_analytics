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

locations.each do |_city, lat_long|
  id, name = AccuWeatherForecast.find_nearest_weather_station(lat_long[0], lat_long[1])
  puts id, name
  forecast = AccuWeatherForecast.new(id)
end
exit


