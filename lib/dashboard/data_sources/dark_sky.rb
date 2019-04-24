# Dark Sky weather interfaces
# need to set environment variable ENERGYSPARKSDARKSKYFORECASTAPIKEY, ENERGYSPARKSDARKSKYHISTORICAPIKEY
#

require 'net/http'
require 'json'
require 'date'
require 'awesome_print'

class DarkSkyWeatherInterface
  def initialize
    @forecast_api_key = ENV['ENERGYSPARKSDARKSKYFORECASTAPIKEY']
    @historic_api_key = ENV['ENERGYSPARKSDARKSKYHISTORICAPIKEY']
  end

  def weather_forecast(latitude, longitude)
    url = weather_forecast_12_day_url(latitude, longitude)
    data = download_data(url)
    # ap(data)
    results = current_conditions(data)
    results.merge!(hourly_data(data))
    results
  end

  def historic_temperatures(latitude, longitude, start_date, end_date)
    distance_to_weather_station, historic_weather_data = download_historic_weather(latitude, longitude, start_date, end_date + 1)
    historic_weather_data, bad_data = document_missing_and_remove_nil_readings(historic_weather_data, start_date, end_date + 1)
    interpolated_historic_weather_data = interpolate_missing_data(historic_weather_data, start_date, end_date)
    bad_data += check_for_jumps_in_data(interpolated_historic_weather_data)
    temperature_data = convert_to_date_hash_to_x48_temperatures(interpolated_historic_weather_data, start_date, end_date)
    percent_bad = bad_data.empty? ? 0.0 : (bad_data.length / (24 * temperature_data.length))
    [distance_to_weather_station, temperature_data, percent_bad, bad_data]
  end

  private def download_historic_weather(latitude, longitude, start_date, end_date)
    distance_to_weather_station = nil
    historic_weather_data = {}
    (start_date..end_date).each do |date|
      data = download_one_days_historic_weather(latitude, longitude, date)
      distance_to_weather_station = data[:distance_to_nearest_station_km]
      historic_weather_data.merge!(data.select{ |time_key, _temperature| !%i[distance_to_nearest_station_km].include?(time_key) })
    end
    [distance_to_weather_station, historic_weather_data]
  end

  private def document_missing_and_remove_nil_readings(historic_weather_data, start_date, end_date)
    bad_data = []
    points_to_remove = []
    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        time = Time.new(date.year, date.month, date.day, hour, 0)
        if !historic_weather_data.key?(time)
          bad_data.push("Missing data at #{time}")
        elsif historic_weather_data[time].nil?
          bad_data.push("Nil weather reading at #{time}")
        elsif historic_weather_data[time][:temperature].nil?
          bad_data.push("Nil temperature reading at #{time}")
          points_to_remove.push(time)
        elsif historic_weather_data[time][:temperature] < -10.0
          bad_data.push("Very low temperature reading at #{time} of #{historic_weather_data[time][:temperature]}")
        elsif historic_weather_data[time][:temperature] > 38.0
          bad_data.push("Very high temperature reading at #{time} of #{historic_weather_data[time][:temperature]}")
        end
      end
    end
    points_to_remove.each do |time|
      historic_weather_data.delete(time)
    end
    [historic_weather_data, bad_data]
  end

  private def temperatures_only(historic_weather_data)
    historic_weather_data.transform_values{ |weather| weather[:temperature] }
  end

  private def time_in_seconds(historic_weather_data)
    historic_weather_data.transform_keys{ |time| time.to_i}
  end

  private def convert_weather_data_for_interpolation(historic_weather_data)
    converted_weather = temperatures_only(historic_weather_data)
    time_in_seconds(converted_weather)
  end


  private def interpolate_missing_data(historic_weather_data, start_date, end_date)
    interpolated_historic_weather_data = {}
    interpolator = Interpolate::Points.new(convert_weather_data_for_interpolation(historic_weather_data))
    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        [0, 30].each do |halfhour|
          t = Time.new(date.year, date.month, date.day, hour, halfhour, 0)
          interpolated_historic_weather_data[t] = interpolator.at(t.to_i).round(2)
        end
      end
    end
    interpolated_historic_weather_data
  end

  def check_for_jumps_in_data(interpolated_historic_weather_data)
    bad_data = []
    interpolated_historic_weather_data.each_with_index do |(time, _weather_data), index|
      next if index >= interpolated_historic_weather_data.values.length - 1 # skip very last iteration [index+ 1]
      temp_change = (interpolated_historic_weather_data.values[index] - interpolated_historic_weather_data.values[index + 1]).magnitude
      if temp_change > 5.0
        bad_data.push("Large jump in temperature of #{temp_change} at #{time}")
      end
    end
    bad_data
  end

  private def convert_to_date_hash_to_x48_temperatures(interpolated_historic_weather_data, start_date, end_date)
    weather_data = Hash.new{ |h, k| h[k] = [] }
    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        [0, 30].each do |halfhour|
          t = Time.new(date.year, date.month, date.day, hour, halfhour, 0)
          weather_data[date].push(interpolated_historic_weather_data[t])
        end
      end
    end
    weather_data
  end

  private def download_one_days_historic_weather(latitude, longitude, date)
    time = Time.new(date.year, date.month, date.day)
    url = historic_weather_data_url(latitude, longitude, time)
    data = download_data(url)
    # ap(data)
    results = hourly_data(data)
    results.merge!(nearest_station_km(data))
    results
  end

  private def download_data(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  private def weather_forecast_12_day_url(latitude, longitude)
    "https://api.darksky.net/forecast/#{@forecast_api_key}/#{latitude},#{longitude}?units=si&extend=hourly"
  end

  private def historic_weather_data_url(latitude, longitude, time)
    time_seconds_since_1970 = time.to_f.round(0)
    "https://api.darksky.net/forecast/#{@historic_api_key}/#{latitude},#{longitude},#{time_seconds_since_1970}?units=si"
  end

  private def nearest_station_km(data)
    {
      distance_to_nearest_station_km: data['flags']['nearest-station']
    }
  end

  private def current_conditions(data)
    {
      current: {
        temperature: data['currently']['temperature'],
        time: Time.at(data['currently']['time'])
      }
    }
  end

  private def hourly_data(data)
    forecast = {} # or historic data - same interface
    hourly_data = data['hourly']['data']
    hourly_data.each do |hours_forecast|
      forecast[Time.at(hours_forecast['time'])] = {
        temperature:  hours_forecast['temperature'],
        cloud_cover:  hours_forecast['cloudCover'],
        wind_speed:   hours_forecast['windSpeed']
      }
    end
    forecast
  end

  private def fahrenheit_to_centigrade_conversion(fahrenheit)
    ((fahrenheit - 32.0) * 5.0 / 9.0).round(2)
  end
end
