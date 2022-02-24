# wrapper around a weather forecast download
# over the years free APIs have come and gone: yahoo, accu and/or
# reduced their functionality: met office data point
# forecast come back in differing formats, so try to separate
# out the data provided from the applications use of it
# currently caches requests to within MIN_CACHE_DISTANCE_KM
# of an existing request
class WeatherForecast
  attr_reader :forecast

  def self.nearest_cached_forecast_factory(latitude, longitude, asof_date)
    f = WeatherForecastCache.instance.nearest_cached_forecast(latitude, longitude, asof_date)
    WeatherForecast.new(f)
  end

  def start_date
    @forecast.keys.first
  end

  def end_date
    @forecast.keys.last
  end

  def average_temperature_within_hours(date, start_hour, end_hour)
    average_data_within_hours(date, start_hour,  end_hour, :temperature)
  end

  def average_cloud_cover_within_hours(date, start_hour, end_hour)
    average_data_within_hours(date, start_hour,  end_hour, :cloud_cover)
  end

  def average_data_within_hours(date, start_hour, end_hour, type)
    data = @forecast[date].select { |d| d[:time_of_day].hour.between?(start_hour, end_hour) }
    data.empty? ? nil : data.map { |d| d[type] }.sum / data.length
  end

  def self.truncated_forecast(weather, date)
    WeatherForecast.new(weather.forecast.select { |d, _f| d <= date })
  end

  private

  def initialize(forecast)
    @forecast = forecast
  end
end

class WeatherForecastCache
  include Logging
  include Singleton
  MIN_CACHE_DISTANCE_KM=30

  def nearest_cached_forecast(latitude, longitude, asof_date)
    download_cached_forecast(latitude, longitude, asof_date) if cache(asof_date).empty?

    nearest = sort_nearest(latitude, longitude, asof_date)
    nearest_latitude = nearest.keys.first[0]
    nearest_longitude = nearest.keys.first[1]

    if LatitudeLongitude.distance(latitude, longitude, nearest_latitude, nearest_longitude) < MIN_CACHE_DISTANCE_KM
      nearest.values.first
    else
      download_cached_forecast(latitude, longitude, asof_date)
    end
  end

  private

  def sort_nearest(from_latitude, from_longitude, asof_date)
    cache(asof_date).sort_by do |forecast|
      to_latitude, to_longitude = forecast.keys.first
      LatitudeLongitude.distance(from_latitude, from_longitude, to_latitude, to_longitude)
    end.first
  end

  def download_cached_forecast(latitude, longitude, asof_date)
    add_cache(download_forecast(latitude, longitude), asof_date)
  end

  def add_cache(forecast_data, _asof_date)
    # monkey patched in test environment to speedup, save API requests
    # asof_date not used in live environment
    cache(asof_date).push(forecast_data)
  end

  def cache(_asof_date)
    # monkey patched in test environment to speedup, save API requests
    # asof_date not used in live environment
    @cache ||= []
  end

  def download_forecast(latitude, longitude)
    logger.info "Downloading a forecast for #{latitude} #{longitude}"
    { [latitude, longitude] => VisualCrossingWeatherForecast.new.forecast(latitude, longitude) }
  end
end
