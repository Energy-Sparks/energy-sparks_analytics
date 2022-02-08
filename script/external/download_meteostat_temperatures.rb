require 'require_all'
require 'date'
require_relative '../lib/dashboard.rb'

def write_csv(filename, data, append)
  mode = append ? "Appending" : "Writing"
  puts "    #{mode} csv file #{filename}: #{data.length} items from #{data.keys.first} to #{data.keys.last}"
  File.open(filename, append ? 'a' : 'w') do |file|
    data.each do |date, one_days_values|
      dts = date.strftime('%Y-%m-%d')
      file.puts("#{dts}," + one_days_values.join(','))
    end
  end
end

def download(latitude, longitude, start_date, end_date)
  met = MeteoStat.new
  met.historic_temperatures(latitude, longitude, start_date, end_date)
end

def nearest_weather_stations(latitude, longitude)
  met = MeteoStat.new
  met.nearest_weather_stations(latitude, longitude, 4, 100000)
end

start_date = Date.new(2016, 1, 1)
end_date   = Date.new(2020, 11, 10)

AreaNames::AREA_NAMES.each do |area_name, config|
  puts "Doing #{area_name} #{config[:latitude]} #{config[:longitude]} #{config[:temperature_filename]}"
  ap nearest_weather_stations(config[:latitude], config[:longitude])
  temperatures = download(
      config[:latitude],
      config[:longitude],
      start_date,
      end_date
    )
    filename = 'InputData\\' + config[:temperature_filename]
    write_csv(filename, temperatures[:temperatures], false)
    ap temperatures[:missing]
end
