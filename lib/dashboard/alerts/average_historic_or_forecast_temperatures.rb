# gets a mix of historic or forecast (dark sky) temperatures
# used to cope with ambiguous alert asof_dates where meter
# data is running late, and so running an alert for 'today'
# might actually be for a few days ago, where we can use
# historic data rather than the forecast
class AverageHistoricOrForecastTemperatures
  def initialize(school)
    @school = school
  end

  def calculate_average_temperature_for_week_following(asof_date)
    calculate_average_temperature_from_forecast_or_historic(asof_date, 7)
  end

  private def calculate_average_temperature_from_forecast_or_historic(asof_date, days = 7)
    temperatures = []
    (asof_date...(asof_date + days)).each do |date|
      if date <= @school.temperatures.end_date # use historic data if available
        temperatures.push(@school.temperatures.average_temperature(date))
      elsif date < Date.today # not ideal, we are somwehere between the historic data and the asof_date, just use current
        puts '=================Dark Sky request==========================='
        temperatures.push(weather_forecast[:current_temperature])
      else # use forecast
        puts '=================Dark Sky request==========================='
        temperatures.push(average_weather_component(weather_forecast[:forecast], date, 0,  23, :temperature))
      end
    end
    temperatures.sum / temperatures.length
  end

  private def weather_forecast
    @weather_forecast ||= download_weather_forecast
  end

  private def download_weather_forecast
    latitude, longitude = AreaNames.latitude_longitude(AreaNames.key_from_name(@school.area_name))
    raise EnergySparksUnexpectedSchoolDataConfiguration.new('Cant find latitude for school, not setup?') if latitude.nil?
    weather = DarkSkyWeatherInterface.new.weather_forecast(latitude, longitude)
    current = weather[:current]
    weather.delete(:current)
    {
      forecast: weather,
      current_temperature: current[:temperature]
    }
  end

  # copied from AlertHeatingOnOff (PH, 20Aug2019) refactor to share code
  private def average_weather_component(weather, date, start_hour, end_hour, type)
    sample_forecasts = weather.select { |datetime, forecast| date == convert_time_to_date(datetime) && (start_hour..end_hour).to_a.include?(datetime.hour) }
    return nil if sample_forecasts.length < 3 # if not enough data
    forecast_by_type = sample_forecasts.values.map { |samples| samples[type] }
    forecast_by_type.sum / forecast_by_type.length
  end

  private def convert_time_to_date(time)
    Date.new(time.year, time.month, time.day)
  end
end
