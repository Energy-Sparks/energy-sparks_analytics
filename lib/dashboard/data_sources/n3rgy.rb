module MeterReadingsFeeds

  class N3rgy
    include Logging
    
    def initialize(api_key: ENV['N3RGY_APP_KEY'], production: false, debugging: nil)
      @api_key = api_key
      @production = production
      @debugging = debugging
    end

    def grant_trusted_consent(mpxn, file_link)
      url = consent_base_url + 'consents/add-trusted-consent'
      log("JSON: #{url}")
      config = {
        'mpxn'        => mpxn.to_s,
        'apiKey'      => @api_key,
        'evidence'    => file_link,
        'moveInDate'  => '2012-01-01'
      }
      response = Faraday.post(url) do |req|
        req.headers['Authorization'] = @api_key
        req.body = config.to_json
      end
      log(response)
      response
    end

    # PH: this currently doesn't work, not sure why having read
    #     both the API manual and their github Python example...
    def withdraw_trusted_consent(mpxn)
      url = consent_base_url + 'consents/withdraw-consent?mpxn=' + mpxn.to_s
      response = execute_json(url)
      log(response)
      response
    end

    # request to CIN based consent system via IHD - currently not used,
    # but tested and working
    def session_id(mpxn)
      url = consent_base_url + 'consents/sessions'
      log("JSON: #{url}")

      data = {
        'mpxn'        => mpxn.to_s,
        'apiKey'      => @api_key
      }

      resp = Faraday.post(url) do |req|
        req.headers['Authorization'] = @api_key
        req.body = data.to_json
      end
      response = JSON.parse(resp.body)
      log(response)
      response['sessionId']
    end

    def mpxns
      @mpxns ||= get_json_data['entries'].map(&:to_i)
    end

    def mpxn_status(mpxn)
      response = get_json_data(mpxn: mpxn)
      if response.key?('errors') && response['errors'][0]['code'] == 404
        :not_available
      elsif response.key?('errors') && response['errors'][0]['code'] == 403
        :available_not_consented
      else
        :permissioned_and_data_available
      end
    end

    def start_end_date(mpxn, fuel_type = nil, element = nil)
      fuel_type = fuel_type(mpxn) if fuel_type.nil?
      check_reading_types(mpxn, fuel_type)
      element = meter_element(mpxn, fuel_type, :consumption) if element.nil?
      # PH: this API call gets previous days data as well; returns [] if meter not up to date
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: 'consumption', element: element)
      start_date = roll_forward_start_date(response['availableCacheRange']['start'])
      end_date   = roll_back_end_date(response['availableCacheRange']['end'])
      [start_date, end_date]
    end

    def historic_readings(mpxn, start_date, end_date)
      kwhs = historic_readings_kwh_x48(mpxn, start_date, end_date)
      £s   = historic_readings_£_x48(mpxn, start_date, end_date)
      {
        kwhs:             kwhs[:readings],
        missing_kwh:      kwhs[:missing_readings],
        
        kwh_tariffs:      £s[:kwh_tariffs],
        standing_charges: £s[:standing_charges],
        missing_£:        £s[:missing_readings],
      }
    end

    def historic_readings_kwh_x48(mpxn, start_date, end_date)
      fuel_type = fuel_type(mpxn)
      check_reading_types(mpxn, fuel_type)
      element = meter_element(mpxn, fuel_type, :consumption)
      start_date, end_date = start_end_date(mpxn, fuel_type, element)
      processed_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
    end

    def historic_readings_£_x48(mpxn, start_date, end_date)
      fuel_type = fuel_type(mpxn)
      check_reading_types(mpxn, fuel_type)
      element = meter_element(mpxn, fuel_type, :tariff)
      start_date, end_date = start_end_date(mpxn, fuel_type, element)
      processed_meter_readings_£(mpxn, fuel_type, element, start_date, end_date)
    end

    def fuel_type(mpxn)
      response = get_json_data(mpxn: mpxn)
      types = response['entries']
      return nil if types.nil?
      # PH: not entirely clear why you might want more than one fuel type per meter?
      raise EnergySparksUnexpectedStateException, "More than one fuel type #{types.join(' + ')}" if types.length > 1
      raise EnergySparksUnexpectedStateException, 'No fuel type' if types.length == 0
      types[0].to_sym
    end

    private

    def check_reading_types(mpxn, fuel_type)
      types = reading_types(mpxn, fuel_type)
      unless types.length == 2 && types.include?(:consumption) && types.include?(:tariff)
        raise EnergySparksUnsupportedFunctionalityException, "Expecting consumption & tariff reading types, got: #{types.map(&:to_s).join(' + ')}"
      end
    end

    def reading_types(mpxn, fuel_type)
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s)
      response['entries'].map(&:to_sym)
    end

    def meter_element(mpxn, fuel_type, data_type)
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type.to_s)
      elements = response['entries']
      raise EnergySparksUnexpectedStateException, 'no elements' if elements.length == 0
      # PH suspects we will need 2 x mpxn to be returned e.g. a XXXXXXXXX/1 version and a XXXXXXXXX/2 version
      # which breaks the front end integer mpxn convention
      raise EnergySparksUnsupportedFunctionalityException, "Twin Element meters currently not supported: #{elements.join(' + ')}" if elements.length > 1
      elements[0]
    end

    def to_datetime(date_str)
      DateTime.strptime(date_str, '%Y%m%d%H%M')
    end

    def to_date2(date_str)
      Date.strptime(date_str, '%Y-%m-%d')
    end

    def to_date3(date_str)
      Date.strptime(date_str, '%Y%m%d')
    end

    def roll_forward_start_date(start_date)
      dt = to_datetime(start_date)
      d = dt.to_date
      dt.hour > 0 || dt.minute > 0 ? d + 1 : d
    end

    def roll_back_end_date(end_date)
      dt = to_datetime(end_date)
      d = dt.to_date
      dt.hour < 23 || dt.minute < 30 ? d - 1 : d
    end

    def processed_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      raw_kwhs = raw_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      dt_to_kwh = convert_readings_dt_to_kwh(raw_kwhs)
      convert_dt_to_kwh_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
    end

    def processed_meter_readings_£(mpxn, fuel_type, element, start_date, end_date)
      raw_£ = raw_tariffs_£(mpxn, fuel_type, element, start_date, end_date)

      standing_charges = convert_standing_charges_to_range(raw_£[:standing_charges])

      dt_to_£ = convert_readings_dt_to_£(raw_£[:prices])

      tariffs = convert_dt_to_kwh_to_date_to_v_x48(start_date, end_date, dt_to_£)
      
      {
        kwh_tariffs:      tariffs[:readings],
        standing_charges: standing_charges,
        missing_readings: tariffs[:missing_readings],
      }
    end

    def raw_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      download_readings(mpxn, fuel_type, 'consumption', element, start_date, end_date)
    end

    def raw_tariffs_£(mpxn, fuel_type, element, start_date, end_date)
      download_tariffs(mpxn, fuel_type, 'tariff', element, start_date, end_date)
    end

    def download_readings(mpxn, fuel_type, data_type, element, start_date, end_date)
      readings = []
      (start_date..end_date).each_slice(90) do |date_range_max_90days|
        response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type, element: element,
                                    start_date: date_range_max_90days.first, end_date: date_range_max_90days.last)
        readings += response['values']
      end
      readings
    end

    def download_tariffs(mpxn, fuel_type, data_type, element, start_date, end_date)
      standing_charges = []
      prices = []
      (start_date..end_date).each_slice(90) do |date_range_max_90days|
        response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type, element: element,
                                    start_date: date_range_max_90days.first, end_date: date_range_max_90days.last)
        response['values'].each do |slice|
          standing_charges += slice['standingCharges']
          prices += slice['prices']
        end
      end
      {
        standing_charges: standing_charges,
        prices:           prices
      }
    end

    def convert_dt_to_kwh_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
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

    # convert n3rgy standing charge representation to compact
    # hash representation, as per Energy Sparks accounting tariff attributes
    def convert_standing_charges_to_range(standing_charges_date_str)
      sc_sd_to_v = standing_charges_date_str.map.with_index do |current_sc, index|
        [
          to_date2(current_sc['startDate']),
          current_sc['value']
        ]
      end

      standing_charges = {}
      start_date = sc_sd_to_v.first[0]
      value      = sc_sd_to_v.first[1]
      (0...(sc_sd_to_v.length-1)).each do |index|
        if sc_sd_to_v[index][1] != sc_sd_to_v[index+1][1]
          standing_charges[start_date..(sc_sd_to_v[index + 1][0] - 1)] = sc_sd_to_v[index][1]
          start_date = sc_sd_to_v[index+1][0]
        end
      end
      standing_charges[start_date..Date.new(2050,1,1)] = sc_sd_to_v.last[1]

      standing_charges
    end

    def convert_readings_dt_to_kwh(raw_kwhs)
      raw_kwhs.map do |reading|
        [
          DateTime.parse(reading['timestamp']),
          reading['value']
        ]
      end.to_h
    end

    def convert_readings_dt_to_£(raw_£)
      raw_£.map do |reading|
        unless reading.key?('value')
          [
            DateTime.parse(reading['timestamp']),
            # TODO(PH, 24Jan2021) - decode the more complex tariffs
            reading['prices'][0]['value'] / 100.0 # prices seem to be in pence but standing charges in £! - this may be a test data issue
          ]
        else
          [
            DateTime.parse(reading['timestamp']),
            reading['value'] / 100.0 # prices seem to be in pence but standing charges in £! - this may be a test data issue
          ]
        end
      end.to_h
    end

    def datetime_to_30_minutes(date, hour, mins)
      DateTime.new(date.year, date.month, date.day, hour, mins, 0)
    end

    def timestamp_to_date_and_half_hour_index(reading)
      dt = DateTime.parse(reading['timestamp'])
      date = dt.to_date
      half_hour_index = ((dt - date) * 48).to_i
      [date, half_hour_index]
    end

    def get_json_data(mpxn: nil, fuel_type: nil, data_type: nil, element: nil, start_date: nil, end_date: nil)
      url = json_url(mpxn, fuel_type, data_type, element, start_date, end_date)
      execute_json(url)
    end

    def execute_json(url, headers = authorization)
      log("JSON: #{url}")
      connection = Faraday.new(url, headers: headers)
      response = connection.get
      raw_data = JSON.parse(response.body)
      log(raw_data)
      raw_data
    end
  
    def authorization
      { 'Authorization' => @api_key }
    end
  
    def half_hourly_query(start_date, end_date)
      '?start=' + url_date(start_date) + '&end=' + url_date(end_date, true) + '&granularity=halfhour'
    end

    def base_url
      @production ? 'https://api.data.n3rgy.com/' : 'https://sandboxapi.data.n3rgy.com/'
    end

    def consent_base_url
      @production ? 'https://consent.data.n3rgy.com/' : 'https://consentsandbox.data.n3rgy.com/'
    end
  
    def json_url(mpxn, fuel_type, data_type, element, start_date, end_date)
      url = base_url
      url += mpxn.to_s + '/' unless mpxn.nil?
      url += fuel_type + '/' unless fuel_type.nil?
      url += data_type + '/' unless data_type.nil? 
      url += element.to_s unless element.nil?
      url += half_hourly_query(start_date, end_date) unless start_date.nil? || end_date.nil?
      url
    end
  
    def url_date(date, end_date = false)
      end_date ? date.strftime('%Y%m%d2359') : date.strftime('%Y%m%d0000')
    end

    def log(data)
      unless @debugging.nil?
        if @debugging.key?(:logging) && @debugging[:logging]
          if data.is_a?(Hash) || data.is_a?(Array)
            # PH this doesn't appear to work as private method?
            logger.ap data, @debugging[:ap]
          else
            logger.info data
          end
        end
        if @debugging.key?(:puts) && @debugging[:puts]
          if data.is_a?(Hash) || data.is_a?(Array)
            ap data, @debugging[:ap]
          else
            puts data
          end
        end
      end
    end
  end

  class N3rgyTarifffEvaluationResearchIgnore
    def kwh_and_tariff_data_for_mpxn(mpxn)
      puts '=' * 40 + mpxn.to_s + '=' * 40
      data = { kwh: {}, cost: 0.0 }
      type =  get_json_data(mpxn: mpxn)
      type['entries'].each do |fuel_type|
        data_types =  get_json_data(mpxn: mpxn, fuel_type: fuel_type)['entries']
        data_types.each do |data_type| # typically either 'consumption' i.e. kWh or 'tariff' i.e. £
          elements = get_json_data(mpxn: mpxn, fuel_type: fuel_type, data_type: data_type)['entries']
          puts "elements: #{elements.join(',')}"
          elements.each do |element|
            meter_data_type_range = meter_date_range(mpxn, fuel_type, data_type, element)
            puts "Got data between #{meter_data_type_range.first} and #{meter_data_type_range.last} for #{mpxn} #{fuel_type} #{data_type} #{element}"
            d = half_hourly_data(mpxn, meter_data_type_range.first, meter_data_type_range.last, fuel_type, data_type, element)
            data = deep_merge_data(data, d)
          end
        end
      end
      data
    end
  
    private
  
    def deep_merge_data(base, additional)
      {
        kwh:  base[:kwh].merge(additional[:kwh]),
        cost: base[:cost] + additional[:cost]
      }
    end

    # it appears that there is either a single price for a half hour period
    # or two - one above and one below a threshold (volume discount?)
    def process_prices(price_values)
      costs = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour costs]
      thresholds = 0
      unknowns = Hash.new(0)
      price_values.each do |reading|
        date, half_hour_index = timestamp_to_date_and_half_hour_index(reading)
        
        if reading.key?('value')
          cost = reading['value']
          costs[date][half_hour_index] += cost
        end
        if reading.key?('prices') && reading['prices'].is_a?(Array)
          # map then sum to avoid statsample bug; sum on its own crashes
          cost = reading['prices'].map{ |threshold_price| threshold_price['value'] }.sum
          costs[date][half_hour_index] += cost
        end
        if reading.key?('thresholds')
          thresholds  += 1
        end
        reading.each_key do |key|
          if !['prices', 'value', 'thresholds', 'timestamp'].include?(key)
            unknowns[key] += 1
          end
        end
      end
      { costs: costs, thresholds: thresholds, unknowns: unknowns }
    end

    # there is no interface to provide the first and last meter readings
    # this is probably because the first time the data is accessed it needs
    # to make a GSM request of a remote meter, and until it makes this request it doesn't
    # know the data range stored in the meter?
    def meter_date_range(mpxn, fuel_type, data_type, element)
      raw_data = get_json_data(mpxn: mpxn, fuel_type: fuel_type, data_type: data_type, element: element,
                                start_date: Date.today, end_date: Date.today + 1)
      start_date = to_date3(raw_data['availableCacheRange']['start']) + 1
      end_date = to_date3(raw_data['availableCacheRange']['end']) - 1
      start_date..end_date
    end
  
    def process_cost_data(raw_data)
      costs = {}
      raw_data.each_key do |key|
        case key
        when 'values'
          costs = process_cost_values(raw_data['values'])
        when 'resource', 'responseTimestamp', 'start', 'end', 'availableCacheRange'
          # known returned data, currently ignored
        else
          raise StandardError, "Unknown cost attribute #{key}"
        end
      end
  
      puts "keys = #{raw_data.keys}"
      costs
    end
  
    def process_cost_values(cost_values_array)
      standing_charges = 0.0
      prices = {}
      raise StandardError, "Error: more than one cost value set, unexpected, num =  #{cost_values_array.lengthy}" if cost_values_array.length > 1
      cost_values_array[0].each do |key, cost_values|
        case key
        when 'standingCharges'
          cost_values.each do |standing_charge|
            standing_charges += standing_charge['value']
            raise StandardError, "Unknown standard charge type in #{standing_charge.keys}" unless standing_charge.keys.all?{ |key| ['startDate', 'value'].include?(key) }
            puts "Standing charges: #{standing_charges} - TODO: which probably needs to be applied daily until the next change in standing charge"
          end
        when 'prices'
          puts "Got #{cost_values.length} prices"
          prices = process_prices(cost_values)
          puts "sub total £ = #{prices[:costs].values.map(&:sum).sum}"
        else
          raise StandardError, "Unknown cost type #{key}"
        end
      end
      { prices: prices, standing_charges: standing_charges }
    end
  
    def half_hourly_data(mpxn, start_date, end_date, fuel_type, data_type, element = 1)
      kwhs = {}
      total_cost = 0.0
      (start_date..end_date).each_slice(90) do |date_range_max_90days|
        raw_data = get_json_data(mpxn: mpxn, fuel_type: fuel_type, data_type: data_type, element: element,
                                  start_date: date_range_max_90days.first, end_date: date_range_max_90days.last)
  
        case data_type
        when 'consumption'
          kwhs.merge!(process_consumption_data(raw_data))
        when 'tariff'
          costs = process_cost_data(raw_data)
          # TODO: should add in standard charge for each day of date range, not just once?
          cost = costs[:standing_charges] + costs[:prices][:costs].values.map(&:sum).sum
          total_cost += cost
        else
          raise StandardError, "Unknown data type #{data_type}"
        end
        puts raw_data['message'] if raw_data.key?('message')
      end
      puts "total kwhs #{kwhs.values.map(&:sum).sum} costs #{total_cost}"
      {
        kwh:  kwhs,
        cost: total_cost
      }
    end
  
    def process_consumption_data(raw_data)
      readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour kwh]
      raw_data['values'].each do |reading|
        date, half_hour_index = timestamp_to_date_and_half_hour_index(reading)
        kwh = reading['value']
        readings[date][half_hour_index] += kwh
      end
      puts "Processes #{readings.length} dates"
      puts "sub total kwh = #{readings.values.map(&:sum).sum}"
      readings
    end
  end
end
