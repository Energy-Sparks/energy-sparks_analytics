module MeterReadingsFeeds
  class N3rgyDataApi
    include Logging

    class ApiFailure < StandardError; end
    class NotFound < StandardError; end
    class NotAllowed < StandardError; end
    class NotAuthorised < StandardError; end

    DEFAULT_ELEMENT = 1
    DATA_TYPE_CONSUMPTION = 'consumption'
    DATA_TYPE_TARIFF = 'tariff'
    DATA_TYPE_PRODUCTION = 'production'

    def initialize(api_key, base_url, connection=nil)
      @api_key = api_key
      @base_url = base_url
      @connection = connection
    end

    def get_consumption_data(mpxn: nil, fuel_type: nil, element: DEFAULT_ELEMENT, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_CONSUMPTION, element, start_date, end_date)
      get_data(url)
    end

    def get_tariff_data(mpxn: nil, fuel_type: nil, element: DEFAULT_ELEMENT, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_TARIFF, element, start_date, end_date)
      get_data(url)
    end

    def get_production_data(mpxn: nil, fuel_type: nil, element: DEFAULT_ELEMENT, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_PRODUCTION, element, start_date, end_date)
      get_data(url)
    end

    def get_elements(mpxn: nil, fuel_type: nil, reading_type: DATA_TYPE_CONSUMPTION)
      url = make_url(mpxn, fuel_type, reading_type)
      get_data(url)
    end

    def cache_data(mpxn: nil, fuel_type: nil, element: DEFAULT_ELEMENT, reading_type: DATA_TYPE_CONSUMPTION)
      url = make_url(mpxn, fuel_type, reading_type, element)
      get_data(url)
    end

    def read_inventory(mpxn: )
      url = '/read-inventory'
      body = { mpxns: [mpxn] }
      response = connection.post(url) do |req|
        req.headers['Authorization'] = @api_key
        req.body = body.to_json
      end
      JSON.parse(response.body)
    end

    def status(mpxn)
      url = make_url(mpxn)
      get_data(url)
    end

    def fetch(url, retry_interval = 0, max_retries = 0)
      begin
        retries ||= 0
        sleep(retry_interval)
        get_data(url)
      rescue NotAllowed => e
        retry if (retries += 1) <= max_retries
        raise e
      end
    end

    private

    def headers
      { 'Authorization' => @api_key }
    end

    def connection
      @connection ||= Faraday.new(@base_url, headers: headers)
    end

    def get_data(url)
      response = connection.get(url)
      raise NotAuthorised.new(error_message(response)) if response.status == 401
      raise NotAllowed.new(error_message(response)) if response.status == 403
      raise NotFound.new(error_message(response)) if response.status == 404
      raise ApiFailure.new(error_message(response)) unless response.success?
      JSON.parse(response.body)
    end

    def make_url(mpxn, fuel_type = nil, data_type = nil, element = nil, start_date = nil, end_date = nil)
      url = "/"
      url += mpxn.to_s + '/' unless mpxn.nil?
      url += fuel_type.to_s + '/' unless fuel_type.nil?
      url += data_type.to_s + '/' unless data_type.nil?
      url += element.to_s unless element.nil?
      url += half_hourly_query(start_date, end_date + 1) unless start_date.nil? || end_date.nil?
      url
    end

    def half_hourly_query(start_date, end_date)
      '?start=' + url_date(start_date) + '&end=' + url_date(end_date)
    end

    def url_date(date)
      date.strftime('%Y%m%d')
    end

    def error_message(response)
      data = JSON.parse(response.body)
      if data['errors']
        error = data['errors'][0]
        error['message']
      elsif data['message']
        data['message']
      else
        response.body
      end
    rescue => e
      #problem parsing or traversing json, return original api error
      response.body
    end
  end
end
