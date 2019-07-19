# Historic Solar PV Data Download Interface - from Sheffield University
#   2 versions: v1 - to May 2019, v2 - post May 2019
#   need to set environment variable ENERGYSPARKSV2SHEFPVAREAURL, ENERGYSPARKSV2SHEFPVHISTDATAURL
#

require 'net/http'
require 'json'
require 'date'
require 'sun_times'

class SheffieldSolarPVBase
  include Logging

  protected

  def split_time_period_into_chunks(start_date, end_date)
    chunk = 20 # days
    dates = []
    last_date = start_date
    (start_date..end_date).step(chunk) do |date|
      last_date = (date + chunk - 1 < end_date) ? date + chunk - 1 : end_date
      dates.push([date, last_date])
    end
    dates
  end

  def make_url(region_id, start_date, end_date)
    url = 'https://api0.solar.sheffield.ac.uk/pvlive/v1?'
    url += 'region_id=' + region_id.to_s + '&'
    url += 'extra_fields=capacity_mwp,site_count&'
    url += 'start=' + date_to_url_format(start_date, true) + '&'
    url += 'end=' + date_to_url_format(end_date, false)
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
          data_count += 1
        else
          # puts "Nil data at #{datetimestr}"
        end
      end
    end
    logger.info "total yield #{total_yield} items #{data_count}"
    solar_pv_yield
  end

  def download_data_for_region(region_id, name, start_date, end_date)
    url = make_url(region_id, start_date, end_date)
    logger.info "Downloading PV data for region #{name} from #{start_date} to #{end_date} using #{url}"
    download_data(url)
  end

  def download_data_for_climate_zone(latitude, longitude, start_date, end_date)
    region_data = {}
    @area_proxies.each do |proxy|
      proxy_latitude = proxy[:latitude]
      proxy_longitude = proxy[:longitude]
      distance_km = 111*((latitude-proxy_latitude)**2+(longitude-proxy_longitude)**2)**0.5
      logger.info "id #{proxy[:id]} #{proxy[:name]} #{distance_km}"
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
        logger.info message
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
        logger.info message
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
        logger.info message
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
        pv_data = region_data[:data]
        pv_yield = pv_data[dt_30mins]
        pv_values_for_30mins.push(pv_yield)
      end

      weighted_pv_yield = calculate_average(pv_values_for_30mins, names.clone, distances.clone, latitude, longitude, dt_30mins, @yield_diff_criteria)

      averaged_pv_yields[dt_30mins] = weighted_pv_yield
    end
    averaged_pv_yields # {datetime} = yield
  end

  private def convert_to_date_hash_to_x48_pv_yield(solar_pv_data, start_date, end_date)
    pv_data = Hash.new{ |h, k| h[k] = [] }
    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        [0, 30].each do |halfhour|
          t = DateTime.new(date.year, date.month, date.day, hour, halfhour, 0)
          pv_data[date].push(solar_pv_data[t])
        end
      end
    end
    pv_data
  end
end

# Sheffield Historic Solar PV Download - v1 API - valid until end May 2019
class SheffieldSolarPVV1 < SheffieldSolarPVBase
  def initialize(latitude, longitude, area_proxies)
    @latitude = latitude
    @longitude = longitude
    @area_proxies = area_proxies
    @yield_diff_criteria = 0.2
    @errors = []
  end

  # returns a date hash to array of 48 half hourly yield: hash[date] = solar_pv_yields[x48]
  def download_historic_solar_pv_data(climate_zone_name_for_debug_output, start_date, end_date)
    pv_data = {}

    dates = split_time_period_into_chunks(start_date, end_date) # process data in chunks to avoid timeout

    dates.each do |date_range_chunk|
      chunk_start_date, chunk_end_date = date_range_chunk
      logger.info "============Downloading and processing pv data between #{chunk_start_date} #{chunk_end_date} for area #{climate_zone_name_for_debug_output} ============="
      regional_data = download_data_for_climate_zone(@latitude, @longitude, chunk_start_date, chunk_end_date)
      pv_data.merge!(process_regional_data(regional_data, chunk_start_date, chunk_end_date, @latitude, @longitude))
    end

    convert_to_date_hash_to_x48_pv_yield(pv_data, start_date, end_date)
  end
end

# Sheffield Historic Solar PV Download - v2 API - valid from May 2019
class SheffieldSolarPVV2 < SheffieldSolarPVBase
  def initialize
    @v2_historic_interface_url_base = 'https://api0.solar.sheffield.ac.uk/pvlive/v2/gsp/' # ENV['ENERGYSPARKSSHEFFIELDPVV2HISTORICURL']
    @v2_geographic_area_url         = 'https://api0.solar.sheffield.ac.uk/pvlive/v2/gsp_list' # ENV['ENERGYSPARKSSHEFFIELDPVV2AREAURL']
    @yield_diff_criteria = 0.001
  end

  # should run minimum to 10 days, to create overlap for interpolation (missing days data only slightly fault tolerant)
  def historic_solar_pv_data(gsp_id, sunrise_sunset_latitude, sunrise_sunset_longitude, start_date, end_date)
    raise "Error: requested start_date #{start_date} earlier than first available date 2014-01-01" if start_date < Date.new(2014, 1, 1)
    pv_data, meta_data_dictionary = download_historic_data(gsp_id, start_date, end_date)
    datetime_to_yield_hash = process_pv_data(pv_data, meta_data_dictionary, sunrise_sunset_latitude, sunrise_sunset_longitude)
    pv_date_hash_to_x48_yield_array, missing_date_times, whole_day_substitutes = convert_to_date_to_x48_yield_hash(start_date, end_date, datetime_to_yield_hash)
    [pv_date_hash_to_x48_yield_array, missing_date_times, whole_day_substitutes]
  end

  def find_nearest_areas(latitude, longitude, number = 5)
    data = download_nearest_area_data

    meta_data_dictionary      = data['meta']
    geographic_location_data  = data['data']

    location_database = []

    geographic_location_data.each do |location_data|
      one_area = decode_one_area(location_data, latitude, longitude, meta_data_dictionary)
      location_database.push(one_area) unless one_area.nil?
    end

    nearest_areas(location_database, number)
  end

  # ======================= HISTORIC DATA SUPPORT METHODS ================================================

  private def process_pv_data(pv_data, meta_data_dictionary, sunrise_sunset_latitude, sunrise_sunset_longitude)
    datetime_to_yield_hash = convert_raw_data(pv_data, meta_data_dictionary)
    zero_out_noise(datetime_to_yield_hash, sunrise_sunset_latitude, sunrise_sunset_longitude)
  end

  private def convert_to_date_to_x48_yield_hash(start_date, end_date, datetime_to_yield_hash)
    date_to_halfhour_yields_x48 = {}
    missing_date_times = []
    too_little_data_on_day = []
    interpolator = setup_interpolation(datetime_to_yield_hash)

    (start_date..end_date).each do |date|
      missing_on_day = 0
      days_data = []
      (0..23).each do |hour|
        [0, 30].each do |minutes|
          dt = DateTime.new(date.year, date.month, date.day, hour, minutes, 0)
          if datetime_to_yield_hash.key?(dt)
            days_data.push(datetime_to_yield_hash[dt])
          else
            missing_on_day += 1 if hour >= 6 && hour <= 18
            days_data.push(interpolator.at(dt))
            missing_date_times.push(dt)
          end
        end
      end

      if missing_on_day > 5 && date > start_date
        too_little_data_on_day.push(date)
      elsif days_data.sum <= 0.0
        logger.error "Data sums to zero on #{date}"
        puts "Data sums to zero on #{date}"
        too_little_data_on_day.push(date)
      else
        date_to_halfhour_yields_x48[date] = days_data
      end
    end

    whole_day_substitutes = substitute_missing_days(too_little_data_on_day, date_to_halfhour_yields_x48, start_date, end_date)

    [date_to_halfhour_yields_x48, missing_date_times, whole_day_substitutes]
  end

  private def substitute_missing_days(missing_days, data, start_date, end_date)
    substitute_days = {}
    missing_days.each do |missing_date|
      (start_date..(missing_date-1)).reverse_each do |search_date|
        substitute_days[missing_date] = search_date if !substitute_days.key?(missing_date) && data.key?(search_date)
      end
      ((missing_date+1)..end_date).each do |search_date|
        substitute_days[missing_date] = search_date if !substitute_days.key?(missing_date) && data.key?(search_date)
      end
    end
    substitute_days.each do |missing_date, substitute_date|
      data[missing_date] = data[substitute_date]
    end
    substitute_days
  end

  private def setup_interpolation(datetime_to_yield_hash)
    integer_keyed_data = datetime_to_yield_hash.transform_keys { |t| t.to_time.to_i }
    Interpolate::Points.new(integer_keyed_data)
  end

  private def zero_out_noise(datetime_to_yield_hash, latitude, longitude)
    datetime_to_yield_hash.each do |datetime, yield_pv|
      datetime_to_yield_hash[datetime] = 0.0 unless daytime?(datetime, latitude, longitude, 0.5)
      datetime_to_yield_hash[datetime] = 0.0 if yield_pv < @yield_diff_criteria
    end
    datetime_to_yield_hash
  end

  private def convert_raw_data(pv_data, meta_data_dictionary)
    all_pv_yield = {}
    pv_data.each do |halfhour_data|
      time = DateTime.parse(halfhour_data[meta_data_dictionary.index('datetime_gmt')])
      generation = halfhour_data[meta_data_dictionary.index('generation_mw')]
      capacity = halfhour_data[meta_data_dictionary.index('installedcapacity_mwp')]
      next if generation.nil? || capacity.nil?
      yield_pv = generation / capacity
      all_pv_yield[time] = yield_pv
    end
    all_pv_yield
  end

  private def download_historic_data(gsp_id, start_date, end_date)
    pv_data = []
    meta_data_dictionary = nil
    # split request into chunks of 20 to avoid timeout for too big a request
    (start_date..end_date).to_a.each_slice(20).to_a.each do |dates|
      raw_data = download_historic_raw_data(gsp_id, dates.first, dates.last)
      pv_data += raw_data['data']
      meta_data_dictionary = raw_data['meta']
    end
    [pv_data, meta_data_dictionary]
  end

  private def download_historic_raw_data(gsp_id, start_date, end_date)
    url = v2_historic_url(gsp_id, start_date, end_date)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  private def v2_historic_url(gsp_id, start_date, end_date)
    url = @v2_historic_interface_url_base
    url += gsp_id.to_s + '?'
    url += 'start=' + date_to_url_format(start_date, true) + '&'
    url += 'end=' + date_to_url_format(end_date, false)
    url += '&extra_fields=installedcapacity_mwp'
    url
  end

  # ======================= NEAREST AREA SUPPORT METHODS ================================================

  private def nearest_areas(location_database, number = 5)
    nearest_locations = location_database.sort {|loc1, loc2| loc1[:distance_km] <=> loc2[:distance_km] } 
    nearest_locations[0...number]
  end

  private def decode_one_area(location_data, latitude, longitude, meta_data_dictionary)
    # ["gsp_id","gsp_name","gsp_lat","gsp_lon","pes_id","pes_name","n_ggds"]

    gsp_latitude  = location_data[meta_data_dictionary.index('gsp_lat')]
    gsp_longitude = location_data[meta_data_dictionary.index('gsp_lon')]

    return nil if gsp_latitude.nil? || gsp_longitude.nil? # first station 'NATIONAL' always seems to be null

    {
      gsp_id:           location_data[meta_data_dictionary.index('gsp_id')],
      gsp_name:         location_data[meta_data_dictionary.index('gsp_name')],
      latitude:         gsp_latitude,
      longitude:        gsp_longitude, 
      distance_km:      distance_km(latitude, longitude, gsp_latitude, gsp_longitude),
      compass_ordinal:  compass_ordinal(latitude, longitude, gsp_latitude, gsp_longitude)
    }
  end

  private def compass_ordinal(latitude, longitude, gsp_latitude, gsp_longitude)
    degrees = direction(latitude, longitude, gsp_latitude, gsp_longitude)
    compass_points(degrees)
  end

  private def download_nearest_area_data
    uri = URI(@v2_geographic_area_url)
    response = Net::HTTP.get(uri)
    JSON.parse(response) # returns the raw json decoded data
  end

  private def distance_km(latitude, longitude, gsp_latitude, gsp_longitude)
    111.0 * ((latitude - gsp_latitude)**2 + (longitude - gsp_longitude)**2)**0.5
  end

  private def direction(latitude, longitude, gsp_latitude, gsp_longitude)
    latitude_difference  = gsp_latitude - latitude
    longitude_difference = gsp_longitude - longitude
    Math.atan2(longitude_difference, latitude_difference) * 180.0 / Math::PI
  end

  private def compass_points(degrees)
    degrees = (degrees + 22.5) % 360.0 # rotate by 22.5 degrees to provide margin either side of compass ordinal
    index = ((8.0 * degrees) / 360.0).to_i # split into 8 points of compass
    %w[N NE E SE S SW W NW][index]
  end
end
