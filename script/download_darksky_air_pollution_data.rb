# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

start_date  = Date.new(2019, 5, 1)
end_date    = Date.new(2019, 7, 31)

latitude    = 53.3811
longitude   = -1.4701

csv_filename = 'Sheffield air pollution data.csv'

wanted_fields =  {
  temperature:    'temperature',
  rain:           'precipIntensity',
  wind_speed:     'windSpeed',
  wind_direction: 'windBearing',
  ozone:          'ozone'
}

data =  DarkSkyWeatherInterface.new(wanted_fields).historic_weather_data(latitude, longitude, start_date, end_date)

puts "Saving data to #{csv_filename}"

File.open(csv_filename, 'w') do |file|
  file.puts("DateTime," + data.values[0].keys.map{ |key| key.to_s.humanize}.join(','))
  data.each do |datetime, half_hour_weather_data|
    dts = datetime.strftime('%Y-%m-%d %H:%M:%S')
    file.puts("#{dts}," + half_hour_weather_data.values.join(','))
    # duplicate hourly data identically to next half hour to ease excel interpretation
    dts = datetime.strftime('%Y-%m-%d %H:30:%S')
    file.puts("#{dts}," + half_hour_weather_data.values.join(','))
  end
end
