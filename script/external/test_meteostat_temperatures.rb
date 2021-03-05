require 'require_all'
require 'date'
require_relative '../lib/dashboard.rb'

def load_csv_file(filename, meteo)
  data = CSV.read('InputData\\' + filename)
  puts "Loaded #{data.length} rows from #{filename}"
  meteo ? convert_meteo(data) : convert_dark_sky(data)
end

def convert_meteo(data)
  data.map do |row|
    [
      Date.parse(row[0]),
      row[1..48].map(&:to_f)
    ]
  end.to_h
end

def convert_dark_sky(data)
  data[1..10000].map do |row|
    [
      Date.parse(row[1]),
      row[2..49].map(&:to_f)
    ]
  end.to_h
end

def compare_darksky_and_meteostat(area_name, darksky, meteostat)
  start_date = [darksky.keys.min, meteostat.keys.min].max
  end_date   = [darksky.keys.max, meteostat.keys.max].min
  puts "#{area_name}, #{start_date.strftime('%a %d-%m-%Y')},#{end_date.strftime('%a %d-%m-%Y')}"
  darksky_stats   = stats(darksky, start_date, end_date)
  meteostat_stats = stats(meteostat, start_date, end_date)
  puts "#{area_name}, Dark sky:,  #{darksky_stats[:min].round(1)}, #{darksky_stats[:avg].round(1)}, #{darksky_stats[:max].round(1)}, #{darksky_stats[:sd].round(1)}, #{darksky_stats[:n].round(1)}"
  puts "#{area_name}, Meteostat:, #{meteostat_stats[:min].round(1)}, #{meteostat_stats[:avg].round(1)}, #{meteostat_stats[:max].round(1)}, #{meteostat_stats[:sd].round(1)}, #{meteostat_stats[:n].round(1)}"
end

def stats(data, start_date, end_date)
  daily = (start_date..end_date).to_a.map do |date|
    {
      min:  data[date].min,
      max:  data[date].max,
      avg:  data[date].sum / data[date].length,
    }
  end
  min = daily.map{ |days| days[:min] }.min
  max = daily.map{ |days| days[:max] }.max
  avg = daily.map{ |days| days[:avg] }.sum / daily.length
  sd = standard_deviation(data)
  {
    daily:  daily,
    min:    min,
    max:    max,
    avg:    avg,
    sd:     sd,
    n:      daily.length
  }
end

def standard_deviation(data)
  temperatures = data.values.flatten
  EnergySparks::Maths.standard_deviation(temperatures)
end

AreaNames::AREA_NAMES.each do |area_name, config|
  meteostat = load_csv_file(config[:temperature_filename], true)
  darksky = load_csv_file(config[:frontend_darksky_csv_file], false)
  compare_darksky_and_meteostat(area_name, darksky, meteostat)
end
