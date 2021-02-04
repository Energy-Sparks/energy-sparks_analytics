module MeterReadingsFeeds
  class N3rgyData
    include Logging

    attr_reader :raw

    KWH_PER_M3_GAS = 11.1 # this depends on the calorifc value of the gas and so is an approximate average

    # N3RGY_DATA_BASE_URL : 'https://api.data.n3rgy.com/' or 'https://sandboxapi.data.n3rgy.com/'

    def initialize(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_DATA_BASE_URL'], debugging: nil)
      @api_key = api_key
      @base_url = base_url
      @debugging = debugging
    end

    def readings(mpxn, fuel_type, start_date, end_date)
      meter_readings = meter_readings_kwh(mpxn, fuel_type, start_date, end_date)
      { fuel_type =>
          {
            mpan_mprn:        mpxn,
            readings:         convert_date_to_x48_to_one_day_readings(meter_readings[:readings], mpxn, start_date, end_date),
            missing_readings: meter_readings[:missing_readings]
          }
      }
    end

    private

    def meter_readings_kwh(mpxn, fuel_type, start_date, end_date)
      data = consumption_data(mpxn, fuel_type, start_date, end_date)
      dt_to_kwh = convert_readings_dt_to_kwh(data[:values], data[:units])
      convert_dt_to_v_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
    end

    def convert_date_to_x48_to_one_day_readings(raw_meter_readings, mpan_mprn, start_date, end_date)
      meter_readings = {}
      (start_date..end_date).each do |date|
        if raw_meter_readings.key?(date)
          meter_readings[date] = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, raw_meter_readings[date])
        else
          meter_readings[date] = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, Array.new(48, 0.0))
          message = "Warning: missing meter readings for #{mpan_mprn} on #{date}"
          logger.warn message
        end
      end
      meter_readings
    end

    # returns hash with consumption data
    # {
    #   values: [{value: 1.449, timestamp: "2019-01-01 00:00"}, ..],
    #   start_date: "201812242330",
    #   end_date:"201905160230",
    #   units: 'kWh'
    # }
    def consumption_data(mpxn, fuel_type, start_date, end_date)
      readings = {}
      readings[:values] = []
      (start_date..end_date).each_slice(90) do |date_range_max_90days|
        response = api.get_consumption_data(mpxn: mpxn,
                                            fuel_type: fuel_type.to_s,
                                            start_date: date_range_max_90days.first,
                                            end_date: date_range_max_90days.last)
        readings[:values] += response['values']
        readings[:start_date] = response['availableCacheRange']['start']
        readings[:end_date] = response['availableCacheRange']['end']
        readings[:units] = response['unit']
      end
      readings
    end

    def convert_readings_dt_to_kwh(raw_kwhs, units)
      adjust_kwh_units = unit_adjustment(units)
      raw_kwhs.map do |reading|
        [
          DateTime.parse(reading['timestamp']),
          reading['value'] * adjust_kwh_units
        ]
      end.to_h
    end

    def unit_adjustment(units)
      if units.nil? || units == 'kWh' # W capitalised by incoming feed
        1.0
      elsif units == 'm3'
        KWH_PER_M3_GAS
      else
        raise EnergySparksUnexpectedStateException, "Unexpected unit type #{units}"
      end
    end

    def convert_dt_to_v_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
      missing_readings = []
      readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) }

      # iterate through data at fixed time intervals
      # so missing date times can be spotted
      (start_date..end_date).each do |date|
        (0..23).each do |hour|
          [0, 30].each_with_index do |mins30, hh_index|
            dt = datetime_to_30_minutes(date, hour, mins30)
            # dt = adjust_to_bst(dt) if adjust_to_bst # raw data in UTC, convert to local time
            if dt_to_kwh.key?(dt)
              readings[date][hour * 2 + hh_index] = dt_to_kwh[dt]
            else
              missing_readings.push(dt)
            end
          end
        end
      end
      {
        readings:         readings,
        missing_readings: missing_readings
      }
    end

    def datetime_to_30_minutes(date, hour, mins)
      DateTime.new(date.year, date.month, date.day, hour, mins, 0)
    end

    def api
      @api ||= N3rgyDataApi.new(@api_key, @base_url, @debugging)
    end
  end
end
