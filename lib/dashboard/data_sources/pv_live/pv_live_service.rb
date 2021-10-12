require 'date'
require 'sun_times'
require 'tzinfo'

module DataSources
  #Provides higher level interface to PVLive API to support bulk downloads,
  #conversion of data into preferred structure, interpolation of missing values,
  #determination of nearest areas, etc
  class PVLiveService

    def initialize(pv_live_api=DataSources::PVLiveAPI.new)
      @pv_live_api = pv_live_api
      @yield_diff_criteria = 0.001
      @schools_timezone = TZInfo::Timezone.get('Europe/London')
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
      data = @pv_live_api.gsp_list

      meta_data_dictionary      = data[:meta]
      geographic_location_data  = data[:data]

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

      date_to_halfhour_yields_x48 = date_to_halfhour_yields_x48.sort.to_h

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
        datetime_to_yield_hash[datetime] = 0.0 unless daytime?(datetime, latitude, longitude, -0.5)
        datetime_to_yield_hash[datetime] = 0.0 if yield_pv < @yield_diff_criteria
      end
      datetime_to_yield_hash
    end

    # check for sunrise (margin = hours after sunrise, before sunset test applied)
    private def daytime?(datetime, latitude, longitude, margin_hours)
      sun_times = SunTimes.new

      sunrise = sun_times.rise(datetime, latitude, longitude)
      sr_criteria = sunrise + 60 * 60 * margin_hours
      sr_criteria_dt = DateTime.parse(sr_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

      sunset = sun_times.set(datetime, latitude, longitude)
      ss_criteria = sunset - 60 * 60 * margin_hours
      ss_criteria_dt = DateTime.parse(ss_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

      datetime > sr_criteria_dt && datetime < ss_criteria_dt
    end

    private def convert_raw_data(pv_data, meta_data_dictionary)
      all_pv_yield = {}
      pv_data.each do |halfhour_data|
        dts = halfhour_data[meta_data_dictionary.index('datetime_gmt')]
        gmt_time = DateTime.parse(dts)
        time = adjust_to_bst(gmt_time)
        generation = halfhour_data[meta_data_dictionary.index('generation_mw')]
        capacity = halfhour_data[meta_data_dictionary.index('installedcapacity_mwp')]
        next if generation.nil? || capacity.nil?
        yield_pv = generation / capacity
        all_pv_yield[time] = yield_pv
      end
      all_pv_yield
    end

    # silently deal with the case of the Autumn time zone change where the local time
    # around midnight exists twice - in this case just use the UTC time;
    # the same issue occurs in Spring where an hour of local time doesn't exist
    # in both cases given it is dark it doesn't matter
    # and the numbers are relatively constant, this is 'ok'
    private def adjust_to_bst(datetime)
      begin
        @schools_timezone.utc_to_local(datetime)
      rescue TZInfo::AmbiguousTime, TZInfo::PeriodNotFound => _e
        datetime
      end
    end

    private def download_historic_data(gsp_id, start_date, end_date)
      pv_data = []
      meta_data_dictionary = nil
      # split request into chunks of 20 to avoid timeout for too big a request
      (start_date..end_date).to_a.each_slice(20).to_a.each do |dates|
        raw_data = @pv_live_api.gsp(gsp_id, dates.first, dates.last)
        pv_data += raw_data[:data]
        meta_data_dictionary = raw_data[:meta]
      end
      [pv_data, meta_data_dictionary]
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

    private def distance_km(latitude, longitude, gsp_latitude, gsp_longitude)
      LatitudeLongitude.distance(latitude, longitude, gsp_latitude, gsp_longitude)
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
end
