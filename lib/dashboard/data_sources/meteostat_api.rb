class MeteoStatApi
  def initialize(api_key)
    @api_key = api_key
  end

  def historic_temperatures(latitude, longitude, start_date, end_date, altitude)
    get(historic_temperatures_url(latitude, longitude, start_date, end_date, altitude))
  end

  def nearby_stations(latitude, longitude, number_of_results, within_radius_km)
    get(nearby_stations_url(latitude, longitude, number_of_results, within_radius_km))
  end

  def find_station(identifier)
    get(find_station_url(identifier))
  end

  private

  def historic_temperatures_url(latitude, longitude, start_date, end_date, altitude)
    'https://api.meteostat.net/v2/point/hourly' +
      '?lat='     + latitude.to_s +
      '&lon='     + longitude.to_s +
      '&alt='     + altitude.to_i.to_s +
      '&start='   + url_date(start_date) +
      '&end='     + url_date(end_date) +
      '&tz=Europe/London'
  end

  def nearby_stations_url(latitude, longitude, number_of_results, within_radius_km)
    'https://api.meteostat.net/v2/stations/nearby' +
      '?lat='     + latitude.to_s +
      '&lon='     + longitude.to_s +
      '&limit='   + number_of_results.to_i.to_s +
      '&radius='  + within_radius_km.to_i.to_s
  end

  def find_station_url(identifier)
    "https://api.meteostat.net/v2/stations/search?query=#{identifier}"
  end

  def url_date(date)
    date.strftime('%Y-%m-%d')
  end

  def headers
    { 'x-api-key' => @api_key }
  end

  def get(url)
    # there seem to be status 429 failures - if you make too
    # many requests in too short a time
    back_off_sleep_times = [0.1, 0.2, 0.5, 1.0, 5.0]
    connection = Faraday.new(url, headers: headers)
    response = nil
    back_off_sleep_times.each do |time_seconds|
      response = connection.get
      break if response.status == 200
      sleep time_seconds
    end
    raise StandardError, "Timed out after #{back_off_sleep_times.length} attempts" if response.status != 200
    JSON.parse(response.body)
  end
end
