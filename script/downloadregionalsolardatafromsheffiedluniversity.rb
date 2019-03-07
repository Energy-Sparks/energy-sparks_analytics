# BATCH Process to download solar PV data from Sheffield University (c) Energy Sparks 2018-
#
# does regional triangulated weighting from a series of local PV regions as defined by Sheffield University
# outputs the results CSV files - one for each climate zone
#
# Sheffield overview https://www.solar.sheffield.ac.uk/pvlive/api/
#
# Nearest regions: https://api0.solar.sheffield.ac.uk/pvlive/v1/gsp_list
# 152	Iron Acton	IROA	51.56933	-2.47937	0.210050103
# 198	Melksham	MELK	51.39403	-2.14938	0.220656804
# 253	Seabank	SEAB	51.53663	-2.66869	0.332740249
#
# get data: url = 'https://api0.solar.sheffield.ac.uk/pvlive/v1?region_id=253&extra_fields=installedcapacity_mwp,site_count&start=2018-05-01T12:00:00&end=2018-05-08T23:59:59'
#
# FYI: the terminology usage in the code can be a little confusing, the term 'climate zone' more closely replated to the term used
#      in Energy Sparks e.g. 'Bath' and defined a number of goegraphically related schools
#      the term 'region' is that of the Sheffield solar feed, and related to solar PV regions
#      there are potentially many 'regions' for each 'climate zone'
#      the program triangulates (distance weighted average) PV data from a number of regions
#       to determine a single set of data for an climate zone
#

require 'net/http'
require 'json'
require 'date'
require 'sun_times'

@start_date = Date.new(2018, 12, 11)
@end_date = Date.new(2019, 3, 6)

@climate_zones = {    # probably not the same climate zones as the other inputs, more critical they are local, so schools to west of Bath may need their own 'climate zone'
  'Bath' => { latitude: 51.39,
              longitude: -2.37,
              proxies: [
                          { id: 152, name: 'Iron Acton', code: 'IROA', latitude: 51.56933, longitude: -2.47937 },
                          { id: 198, name: 'Melksham', code: 'MELK', latitude: 51.39403, longitude: -2.14938 },
                          { id: 253, name: 'Seabank', code: 'SEAB', latitude: 51.53663, longitude: -2.66869 }
                        ] 
  },
  'Sheffield' => {  latitude: 53.3811,
                    longitude: -1.4701,
                    proxies: [  
                      { id: 257, name: 'Sheffield City', code: 'SHEC', latitude: 53.37445, longitude: -1.47708 },
                      { id: 207, name: 'Neepsend', code: 'NEEP', latitude: 53.40642, longitude: -1.48696 },
                      { id: 213, name: 'Norton Lees', code: 'NORL', latitude: 53.34823, longitude: -1.46998 },
                    ] 
  },
  'Frome' => {  latitude: 51.2308,
                longitude: -2.3201,
                proxies: [
                  { id: 152, name: 'Iron Acton', code: 'IROA', latitude: 51.56933, longitude: -2.47937 },
                  { id: 198, name: 'Melksham', code: 'MELK', latitude: 51.39403, longitude: -2.14938 },
                  { id: 253, name: 'Seabank', code: 'SEAB', latitude: 51.53663, longitude: -2.66869 }
                ]  
  },
  'Bristol' => {  latitude: 51.4545,
                  longitude: -2.5879,
                  proxies: [
                    { id: 313, name: 'Whitson', code: 'WHSO', latitude: 51.56488, longitude: -2.90742 },
                    { id: 198, name: 'Melksham', code: 'MELK', latitude: 51.39403, longitude: -2.14938 },
                    { id: 253, name: 'Seabank', code: 'SEAB', latitude: 51.53663, longitude: -2.66869 }
                  ]  
  }
}
@yield_diff_criteria = 0.2 # if 3 or more samples, then reject any yields this far away from median

@errors = []

def make_url(region_id, start_date, end_date)
  url = 'https://api0.solar.sheffield.ac.uk/pvlive/v1?'
  url += 'region_id=' + region_id.to_s + '&'
  url += 'extra_fields=capacity_mwp,site_count&'
  url += 'start=' + date_to_url_format(start_date, true) + '&'
  url += 'end=' + date_to_url_format(end_date, false)
  puts url
  url
end

def date_to_url_format(date, start)
  d_url = date.strftime('%Y-%m-%d')
  d_url += start ? 'T00:00:00' : 'T23:59:59'
  d_url
end

# check for sunrise (margin = hours after sunrise, before sunset test applied)
def daytime?(datetime, latitude, longitude, margin_hours)
  sun_times = SunTimes.new

  sunrise = sun_times.rise(datetime, latitude, longitude)
  sr_criteria = sunrise + 60 * 60 * margin_hours
  sr_criteria_dt = DateTime.parse(sr_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

  sunset = sun_times.set(datetime, latitude, longitude)
  ss_criteria = sunset - 60 * 60 * margin_hours
  ss_criteria_dt = DateTime.parse(ss_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

  datetime > sr_criteria_dt && datetime < ss_criteria_dt
end

def distance_to_climate_zone_km(latitude, longitude, proxy)
  proxy_latitude = proxy[:latitude]
  proxy_longitude = proxy[:longitude]
  distance_km = 111*((latitude-proxy_latitude)**2+(longitude-proxy_longitude)**2)**0.5
end

# for a single 'Sheffield region' download half hourly PV data (output, capacity)
# and return a hash of datetime => yield
def download_data(url) 
  solar_pv_yield = {}
  uri = URI(url)
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)
  total_yield = 0.0
  data_count = 0
  data.each do |key, value|
    value.each do |components|
      id, datetimestr, generation, capacity, _stations = components
      unless generation.nil?
        time = DateTime.parse(datetimestr)
        halfhour_yield = generation / capacity
        total_yield += halfhour_yield
        solar_pv_yield[time] = halfhour_yield
        # puts "Download: #{time} #{halfhour_yield}"
        data_count += 1
      else
        # puts "Nil data at #{datetimestr}"
      end
    end
  end
  puts "total yield #{total_yield} items #{data_count}"
  solar_pv_yield
end

def download_data_for_region(region_id, name, start_date, end_date)
  url = make_url(region_id, start_date, end_date)
  puts "Downloading PV data for region #{name} from #{start_date} to #{end_date} using #{url}"
  download_data(url)
end

def download_data_for_climate_zone(climate_zone_name, latitude, longitude, start_date, end_date)
  region_data = {}
  @climate_zones[climate_zone_name][:proxies].each do |proxy|
    proxy_latitude = proxy[:latitude]
    proxy_longitude = proxy[:longitude]
    distance_km = 111*((latitude-proxy_latitude)**2+(longitude-proxy_longitude)**2)**0.5
    puts "id #{proxy[:id]} #{proxy[:name]} #{distance_km}"
    region_id = proxy[:id]
    name = proxy[:name]
    pv_data = download_data_for_region(region_id, name, start_date, end_date)
    region_data[name] = { distance: distance_km, data: pv_data }
  end
  region_data
end

# middle value if odd, next from middle value if even
def median(ary)
  middle = ary.size/2
  sorted = ary.sort_by{ |a| a }
  sorted[middle]
end

def remove_outliers(data, distances, names, datetime)
  bad_indexes = []

  median_yield = median(data)

  # if too far from median remove
  for i in 0..data.length - 1 do
    if data[i] > median_yield + @yield_diff_criteria || data[i] < median_yield - @yield_diff_criteria
      bad_indexes.push(i)
      message = "Warning: rejecting yield for #{names[i]} value #{data[i]} from values #{data.to_s} for #{datetime}"
      puts message
      @errors.push(message)
    end
  end
  # then remove them from the analysis
  bad_indexes.each do |i|
    data.delete_at(i)
    names.delete_at(i)
    distances.delete_at(i)
  end
end

def proximity_weighted_average(data, distances)
  inverse_distance_sum = 0
  weighted_yield_sum = 0
  for i in 0..data.length - 1 do 
    inverse_distance = 1.0 / distances[i]
    weighted_yield_sum += data[i] * inverse_distance
    inverse_distance_sum += inverse_distance
  end
  weighted_yield_sum / inverse_distance_sum
end

def remove_nil_values(data, names, distances, datetime, latitude, longitude)
  bad_indexes = []
  for i in 0..data.length - 1 do
    if data[i].nil?
      bad_indexes.push(i) 
      message = "Warning: nil value for #{datetime} #{names[i]}, ignoring" if daytime?(datetime, latitude, longitude, 1.5)
      puts message
      @errors.push(message)
    end
  end

  # then remove them from the analysis
  bad_indexes.each do |i|
    data.delete_at(i)
    names.delete_at(i)
    distances.delete_at(i)
  end
end

def calculate_average(data, names, distances, latitude, longitude, datetime, criteria)
  remove_nil_values(data, names, distances, datetime, latitude, longitude)
  calculated_yield = 0.0
  if data.length.zero? || (data.length == 1 && data[0].nil?)
    if daytime?(datetime, latitude, longitude, 2)
      message = "Error: no yield data available from any source on #{datetime}"
      puts message
      @errors.push(message)
    end
    calculated_yield = 0.0
  elsif data.length == 1
    calculated_yield = data[0]
  elsif data.length == 2
    calculated_yield = proximity_weighted_average(data, distances)
  else # vote on value
    remove_outliers(data, distances, names, datetime)
    calculated_yield = proximity_weighted_average(data, distances)
  end
  calculated_yield
end

def process_regional_data(regional_data, start_date, end_date, latitude, longitude)
  averaged_pv_yields = {}
  # unpack the distance data for later weighted average
  distances = []
  names = []
  regional_data.each do |name, region_data|
    distances.push(region_data[:distance])
    names.push(name)
  end

  thirty_minutes_step = (1.to_f/24/2)
  start_time = DateTime.new(start_date.year, start_date.month, start_date.day)
  end_time = DateTime.new(end_date.year, end_date.month, end_date.day, 23, 30, 0) # want to iterate to last 30 mins of day (inclusive)

  start_time.step(end_time, thirty_minutes_step).each do |dt_30mins|
    pv_values_for_30mins = []

    # get data for a given 30 minute period for all 'regions'
    regional_data.values.each do |region_data|
      # puts "Looking for data for #{dt_30mins}"
      pv_data = region_data[:data]
      pv_yield = pv_data[dt_30mins]
      pv_values_for_30mins.push(pv_yield)
    end

    weighted_pv_yield = calculate_average(pv_values_for_30mins, names.clone, distances.clone, latitude, longitude, dt_30mins, @yield_diff_criteria)
    
    averaged_pv_yields[dt_30mins] = weighted_pv_yield
    # puts "average yield for #{dt_30mins} = #{weighted_pv_yield}"
  end
  averaged_pv_yields # {datetime} = yield
end

def unique_list_of_dates_from_datetimes(datetimes)
  dates = {}
  datetimes.each do |datetime|
    dates[datetime.to_date] = true
  end
  dates.keys
end

def write_csv(file, filename, data, orientation)
  # implemented using file operations as roo & write_xlsx don't seem to support writing csv and spreadsheet/csv have BOM issues on Ruby 2.5
  puts "Writing csv file #{filename}: #{data.length} items in format #{orientation}"
  if orientation == :landscape
    dates = unique_list_of_dates_from_datetimes(data.keys)
    dates.each do |date|
      line = date.strftime('%Y-%m-%d') << ','
      (0..47).each do |half_hour_index|
        datetime = DateTime.new(date.year, date.month, date.day, (half_hour_index / 2).to_i, half_hour_index.even? ? 0 : 30, 0)
        if  data.key?(datetime)
          if data[datetime].nil?
            line << ','
          else
            line << data[datetime].to_s << ','
          end
        end
      end
      file.puts(line)
    end
  else
    # this bit is untested, so probably needs some work! PH 12 May 2018
    data.each do |datetime, value|
      line << datetime.strftime('%Y-%m-%d %H:%M:%S') << ',' << value.to_s << '\n'
      file.puts(line)
    end
  end  
end

def split_time_period_into_chunks
  chunk = 20 # days
  dates = []
  last_date = @start_date
  (@start_date..@end_date).step(chunk) do |date|
    last_date = (date + chunk - 1 < @end_date) ? date + chunk - 1 : @end_date
    dates.push([date, last_date])
  end
  dates
end

def download_data_for_climate_zones()
  @climate_zones.each do |climate_zone_name, config_data|
    latitude = config_data[:latitude]
    longitude = config_data[:longitude]
    filename = 'pv data ' + climate_zone_name + '.csv'
    File.open(filename, 'w') do |file| 
      dates = split_time_period_into_chunks # process data in chunks to avoid timeout
      dates.each do |date_range_chunk|
        start_date, end_date = date_range_chunk
        puts
        puts "========================Processing a chunk of data between #{start_date} #{end_date}=============================="
        puts
        regional_data = download_data_for_climate_zone(climate_zone_name, latitude, longitude, start_date, end_date)
        pv_data = process_regional_data(regional_data, start_date, end_date, latitude, longitude)
        write_csv(file, filename, pv_data, :landscape)
      end
    end
  end
end

download_data_for_climate_zones

puts "=============Consolidated Error/Warning Messages============="
@errors.each do |error_msg|
  puts error_msg
end
