require 'net/http'
require 'json'
require 'date'
require 'time'
require 'yaml'
require 'amazing_print'

# experimental interface to Met Office Wow historic temperature database
# caches raw data to .\InputData\CachedWOWData to save 10 queries per week starter api limit
# https://mowowprod.portal.azure-api.net/docs/services/57a0bf29e4a58413dcc1131f/operations/57a0bf2ce4a58413f4360cd4/console
# comments:
# 29May2019:
class MetOfficeWOWHistoricTemperatures
  MAX_GAP_BETWEEN_OBSERVATIONS_SECONDS = 120 * 60
  MAX_VALID_TEMPERATURE_DIFFERENCE_FROM_AVERAGE = 2.0
  def initialize
    @api_key = ENV['ENERGYSPARKSMETOFFICEWOW']
  end

  # lists all weather stations
  def all_weather_stations
    # https://apimgmt.www.wow.metoffice.gov.uk/api/observations/geojson?showWowData=off&showOfficialData=off&showDcnnData=off&showRegisteredSites=on

    query = URI.encode_www_form({
      # Request parameters
      'showWowData' => 'off',
      'showOfficialData' => 'off',
      'showDcnnData' => 'off',
      'showRegisteredSites' => 'on'
    })

    if uri.query && !uri.query.empty?
      uri.query += '&' + query
    else
      uri.query = query
    end

    puts uri.query
    exit
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Ocp-Apim-Subscription-Key'] = @api_key
    request['Authorization'] = 'Bearer access_token'
    request.body = "{body}"

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https'){ |http| http.request(request) }

    puts response.body
  end

  def historic_data_query_by_site_id(site_id, start_date, end_date)
    'start_time=' + url_date_format(start_date, true) + '&' +
    'end_time='  + url_date_format(end_date, false) + '&' +
    'site_id=' + site_id.to_s + '&' +
    'showWowData=true&showOfficialData=false'
  end

  def historic_data_query_by_latitude_longitude(latitude, longitude, start_date, end_date, margin_km = 5)
    'start_time='         + url_date_format(start_date, true)                                 + '&' +
    'end_time='           + url_date_format(end_date, false)                                  + '&' +
    'top_left_lat='       + add_latitude_or_longitude(latitude,   +margin_km).round(4).to_s   + '&' +
    'top_left_long='      + add_latitude_or_longitude(longitude,  -margin_km).round(4).to_s   + '&' +
    'bottom_right_lat='   + add_latitude_or_longitude(latitude,   -margin_km).round(4).to_s   + '&' +
    'bottom_right_long='  + add_latitude_or_longitude(longitude,  +margin_km).round(4).to_s
  end

  def add_latitude_or_longitude(tude, km)
    tude + (km / 111.0)
  end

  def url_date_format(date, start_of_day)
    date.strftime('%Y-%m-%d') + (start_of_day ? 'T00:00:00Z' : 'T23:59:59Z')
  end

  def historic_temperature_data_by_site_id(site_id, start_date, end_date)
    query = historic_data_query_by_site_id(site_id, start_date, end_date)
    download_data(query)
  end

  def historic_temperature_data_by_latitude_longitude(latitude, longitude, start_date, end_date, margin_km = 15)
    query = historic_data_query_by_latitude_longitude(51.3751, -2.36172, start_date, end_date, margin_km)
    download_data(query)
  end

  private def download_data(query)
    cached_data = load_cached_data(query)

    return cached_data unless cached_data.nil?

    url = 'https://apimgmt.www.wow.metoffice.gov.uk/api/observations/byversion?' + query
    data = download_historic_temperature_data(url)

    save_data_to_cache(query, data)

    data
  end

  def download_historic_temperature_data(url)
    data = nil
    puts url
    uri = URI(url)

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Ocp-Apim-Subscription-Key'] = @api_key
    request['Authorization'] = 'Bearer access_token'
    request.body = "{body}"

    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      response = http.request(request)
      data = JSON.parse(response.body)
    end
    data
  end

  def load_cached_data(query)
    filename = yaml_filename(query)
    puts "Loading #{filename}"
    return nil unless File.file?(filename)
    YAML::load_file(filename)
  end

  def save_data_to_cache(query, data)
    filename = yaml_filename(query)
    puts "Saving #{filename}"
    File.open(filename, 'w') { |f| f.write(YAML.dump(data)) }
  end

  def yaml_filename(query)
    File.join('./InputData/CachedWOWData/' + query + '.yaml').gsub(/:/, '-')
  end

  def extract_relevant_data(data, latitude, longitude)
    extracted_data = {}
    data.each do |obs|
      site_id = obs['SiteId']
      unless extracted_data.key?(site_id)
        extracted_data[site_id] = {
          latitude:     obs['Latitude'],
          longitude:    obs['Longitude'],
          distance_km:  111*((latitude-obs['Latitude'])**2+(longitude-obs['Longitude'])**2)**0.5,
          observations: {}
        }
      end
      unless obs['ReportEndDateTime'].nil? || obs['DryBulbTemperature_Celsius'].nil?
        date_time = DateTime.parse(obs['ReportEndDateTime'])
        temperature_c = obs['DryBulbTemperature_Celsius'].round(2)
        extracted_data[site_id][:observations][date_time] = temperature_c
      end
    end
    extracted_data
  end

  def process_data(start_date, end_date, extracted_data)
    dt_to_temp = process_raw_data(start_date, end_date, extracted_data)

    date_to_temperatures_x48 = {}

    (start_date..end_date).each do |date|
      date_to_temperatures_x48[date] = []
      (0..23).each do |hour|
        [0, 30].each do |minute|
          date_time = DateTime.new(date.year, date.month, date.day, hour, minute, 0)
          date_to_temperatures_x48[date].push(dt_to_temp.key?(date_time) ? dt_to_temp[date_time] : nil)
        end
      end
    end
    date_to_temperatures_x48
  end

  private def process_raw_data(start_date, end_date, extracted_data)
    date_time_to_temperature = {}
    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        [0, 30].each do |minute|
          temperatures = []
          date_time = DateTime.new(date.year, date.month, date.day, hour, minute, 0)
          extracted_data.each do |_site_id, data|
            temperature = interpolate_temperature(date_time, data[:observations])
            temperatures.push(temperature) unless temperature.nil?
          end
          temperature = vote_on_temperatures(temperatures)
          if temperature.nil?
            puts "Serious problem unable to calculate temperature for #{date_time}"
          else
            temperature = temperature.round(2)
            date_time_to_temperature[date_time] = temperature
          end
        end
      end
    end
    date_time_to_temperature
  end

  private def vote_on_temperatures(temperatures)
    return nil if temperatures.empty?
    return temperatures[0] if temperatures.length == 1
    return nil if temperatures.length == 2 && (temperatures[0] - temperatures[1]).magnitude > MAX_VALID_TEMPERATURE_DIFFERENCE_FROM_AVERAGE
    return (temperatures[0] + temperatures[0]) / 2.0 if temperatures.length == 2
    median_temperature = median(temperatures)
    filtered_temperatures = temperatures.select { |temperature| (temperature - median_temperature).magnitude < MAX_VALID_TEMPERATURE_DIFFERENCE_FROM_AVERAGE }
    if filtered_temperatures.empty?
      puts temperatures
    end
    filtered_temperatures.sum / filtered_temperatures.length
  end

  def median(ary)
    middle = ary.size/2
    sorted = ary.sort_by{ |a| a }
    sorted[middle]
  end

  def date_time_difference_seconds(d1, d2)
    ((d1 - d2) * 24 * 60 * 60).to_i
  end

  private def interpolate_temperature(date_time, observations)
    index_below = observations.keys.bsearch_index { |dts| date_time >= dts }
    if index_below.nil?
      return nil
    else
      if date_time_difference_seconds(date_time, observations.keys[index_below]) > MAX_GAP_BETWEEN_OBSERVATIONS_SECONDS
        return nil
      elsif index_below == observations.length - 1
        observations.values[index_below]
      elsif date_time_difference_seconds(observations.keys[index_below + 1], date_time) > MAX_GAP_BETWEEN_OBSERVATIONS_SECONDS
        return nil
      else
        temperature_difference = observations.values[index_below + 1] - observations.values[index_below]
        time_difference_observed = observations.keys[index_below + 1] - observations.keys[index_below]
        time_difference_wanted = date_time - observations.keys[index_below]
        proportion_temperature_change = time_difference_wanted / time_difference_observed
        temperature = (observations.values[index_below] + (proportion_temperature_change * temperature_difference)).round(2)
        temperature
      end
    end
  end
end


latitide = 51.3751 # Bath
longitude = -2.36172 # Bath
site_id = 24068024 # Paul Wilman Bath = only to Dec 2018
start_date = Date.new(2016, 12, 19)
end_date = Date.new(2017, 2, 19)

start_date = Date.new(2018, 9, 1)
end_date = Date.new(2018, 9, 14)
# end_date = Date.new(2018, 9, 2)

metoffice_wow = MetOfficeWOWHistoricTemperatures.new

# data = metoffice_wow.historic_temperature_data_by_site_id(24068024, start_date, end_date)
data = metoffice_wow.historic_temperature_data_by_latitude_longitude(latitide, longitude, start_date, end_date)

by_site_id = metoffice_wow.extract_relevant_data(data['Object'], latitide, longitude)

by_site_id.each do |site_id, site|
  puts "#{site[:distance_km]} #{site[:observations].length}"
end

data = metoffice_wow.process_data(start_date, end_date, by_site_id)

File.open('bath wow temperatures.csv', 'w') do |file|
  data.each do |date, temperatures_x48|
    line = [date.strftime('%Y-%m-%d')]
    line += temperatures_x48
    file.puts(line.join(','))
  end
end
ap(data)

# ap(by_site_id)
