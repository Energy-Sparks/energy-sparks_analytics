require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

module Logging
  @logger = @logger = Logger.new(File.join(TestDirectory.instance.log_directory, 'weather forecast test.log'))
  logger.level = :debug
end

def print_temperatures(data)
  data.each do |day, hours|
    puts day
    hours.each do |hour|
      puts "    #{hour[:datetime].strftime('%Y-%m-%d %H:%M')} #{sprintf('%4.1f', hour[:temperature])} #{sprintf('%3.0f%%', hour[:cloudcover]*100.0)}"
    end
  end
end

def test_visual_crossing_api
  locations = {
    'Bath'      => [  51.39,    -2.37],
    'Sheffield' => [  53.3811,  -1.4701],
    'Frome'     => [  51.2308,  -2.3201],
    'Bristol'   => [  51.4545,  -2.5879]
  }

  locations.each do |area, (lat, long)|
    puts '=' * 80
    puts "#{area}:"

    data =  VisualCrossingWeatherForecast.new.forecast(lat, long)
    print_temperatures(data)
  end
end

def test_school_forecasts(school_pattern_match, source, asof_date)
  school_list = SchoolFactory.instance.school_file_list(source, school_pattern_match)

  school_list.sort.each do |school_name|
    school = SchoolFactory.instance.load_school(source, school_name)
    forecast = WeatherForecast.nearest_cached_forecast_factory(school.latitude, school.longitude, asof_date)
    forecast_date = forecast.start_date + 4
    t = forecast.average_temperature_within_hours(forecast_date, 8,  16)
    c = forecast.average_cloud_cover_within_hours(forecast_date, 8,  16)
    puts "average temperature = #{t.round(1)} cloud cover = #{(c * 100.0).round(0)}% for #{forecast_date}"
  end
end

if false
  test_visual_crossing_api
else
  test_school_forecasts(['b*'], :unvalidated_meter_data, Date.new(2022, 1, 25))
end
