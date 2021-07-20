module MeterReadingsFeeds

  # To access the data in the JSON interface you need to traverse a tree:
  #
  # MPAN => electricity => consumption => element = 1 => readings = consumption
  #      => electricity => consumption => element = 1 => readings = tariff
  #      => electricity => production  =>  - would assume this works as above but sandbox example has no entries?
  #      => gas         => consumption => element = 1 => readings = consumption
  #      => gas         => consumption => element = 1 => readings = tariff
  #
  class N3rgyRaw
    include Logging

    KWH_PER_M3_GAS = 11.1 # this depends on the calorifc value of the gas and so is an approximate average

    def initialize(api_key, production, debugging)
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

    # doesn't work - suspect only works in production
    # nothing in the documentation about this, but
    # https://github.com/n3rgy/data/blob/master/n3rgy-smartinventory.py
    # contains this:
    #   if apiSrv == "sandbox":
    #     print "Sandbox inventory queries are not supported\n"
    # get code 404: No property could be found with identifier 'read-inventory' in sandbox
    def inventory
      if @production
        url = base_url + 'read-inventory'
        response = execute_json(url)
        log(response)
        response
      else
        { 'read-inventory doesnt work in sandbox environment' => true }
      end
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

    def start_end_date_by_fuel(mpxn, fuel_type, element, data_type)
      check_reading_types(mpxn, fuel_type)
      # PH: this API call gets previous days data as well; returns [] if meter not up to date
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type.to_s, element: element)
      start_date = roll_forward_start_date(response['availableCacheRange']['start'])
      end_date   = roll_back_end_date(response['availableCacheRange']['end'])
      {start_date: start_date, end_date: end_date}
    end

    def units(mpxn, fuel_type, element, data_type)
      check_reading_types(mpxn, fuel_type)
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type.to_s, element: element)
      response['unit'].nil? ? nil : response['unit'].to_sym # example :m3 for gas
    end

    def fuel_types(mpxn)
      response = get_json_data(mpxn: mpxn)
      types = response['entries']
      return nil if types.nil?
      raise EnergySparksUnexpectedStateException, 'No fuel type' if types.length == 0
      types.map(&:to_sym)
    end

    def meter_elements(mpxn, fuel_type, data_type)
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s, data_type: data_type.to_s)
      elements = response['entries']
      # PH suspects we will need 2 x mpxn to be returned e.g. a XXXXXXXXX/1 version and a XXXXXXXXX/2 version
      # which breaks the front end integer mpxn convention
      raise EnergySparksUnsupportedFunctionalityException, "Twin Element meters currently not supported: #{elements.join(' + ')}" if !elements.nil? && elements.length > 1
      elements
    end

    def check_reading_types(mpxn, fuel_type)
      types = reading_types(mpxn, fuel_type)
      unless (types.length == 2 && types.include?(:consumption) && types.include?(:tariff)) ||
        (types.length == 3 && types.include?(:consumption) && types.include?(:production) && types.include?(:tariff))
        raise EnergySparksUnsupportedFunctionalityException, "Expecting consumption && tariff &&|| production reading types, got: #{types.map(&:to_s).join(' + ')}"
      end
    end

    def raw_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      download_readings(mpxn, fuel_type, 'consumption', element, start_date, end_date)
    end

    def raw_tariffs_£(mpxn, fuel_type, element, start_date, end_date)
      download_tariffs(mpxn, fuel_type, 'tariff', element, start_date, end_date)
    end

    def convert_readings_dt_to_kwh(raw_kwhs, mpxn, fuel_type, element, data_type)
      adjust_kwh_units = gas_m3_adjustment(mpxn, fuel_type, element, data_type)

      raw_kwhs.map do |reading|
        [
          DateTime.parse(reading['timestamp']),
          reading['value'] * adjust_kwh_units
        ]
      end.to_h
    end

    # Energy Sparks convention is everything is in £ and not pence
    def convert_readings_dt_to_£(raw_£, mpxn, fuel_type)
      raw_£.map do |reading|
        unless reading.key?('value')
          [
            DateTime.parse(reading['timestamp']),
            # TODO(PH, 24Jan2021) - decode the more complex tariffs
            reading['prices'][0]['value'] / 100.0
          ]
        else
          [
            DateTime.parse(reading['timestamp']),
            reading['value'] / 100.0
          ]
        end
      end.to_h
    end

    def log(data)
      log_private(data)
    end

    # quote from N3rgy support:
    # "in sandbox environment, electricity tariffs have the standing charges in £/day and the TOU prices in pence/kWh. Gas tariffs are in pence/day and pence/kWh.
    # However, in live environment, our system returns always pence/day and pence/kWh."
    def standing_charge_£_units(fuel_type)
      (@production || fuel_type == :gas) ? 100.0 : 1.0
    end

    private

    def gas_m3_adjustment(mpxn, fuel_type, element, data_type)
      units = units(mpxn, fuel_type, element, data_type)

      if units.nil? || units == :kWh # W capitalised by incoming feed
        1.0
      elsif units == :m3
        KWH_PER_M3_GAS
      else
        raise EnergySparksUnexpectedStateException, "Unexpected unit type #{units}"
      end
    end

    def reading_types(mpxn, fuel_type)
      response = get_json_data(mpxn: mpxn, fuel_type: fuel_type.to_s)
      response['entries'].map(&:to_sym)
    end

    def to_datetime(date_str)
      DateTime.strptime(date_str, '%Y%m%d%H%M')
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

    def timestamp_to_date_and_half_hour_index(reading)
      dt = DateTime.parse(reading['timestamp'])
      date = dt.to_date
      half_hour_index = ((dt - date) * 48).to_i
      [date, half_hour_index]
    end

    def get_json_data(mpxn: nil, fuel_type: nil, data_type: nil, element: nil, start_date: nil, end_date: nil)
      @json_cache ||= {}
      url = json_url(mpxn, fuel_type, data_type, element, start_date, end_date)
      @json_cache[url] ||= execute_json(url)
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

    # PH uses this for debugging
    def log_private(data)
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
end
