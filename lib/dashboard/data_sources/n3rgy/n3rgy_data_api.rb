module MeterReadingsFeeds
  class N3rgyDataApi
    include Logging

    class ApiFailure < StandardError; end
    class NotFound < StandardError; end
    class NotAllowed < StandardError; end

    DEFAULT_ELEMENT = 1
    DATA_TYPE_CONSUMPTION = 'consumption'
    DATA_TYPE_TARIFF = 'tariff'
    DATA_TYPE_PRODUCTION = 'production'

    def initialize(api_key, base_url)
      @api_key = api_key
      @base_url = base_url
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

    def read_inventory(mpxn: )
      url = @base_url + 'read-inventory'
      body = { mpxns: [mpxn] }
      response = Faraday.post(url) do |req|
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

      retry_options = {}

      # retry_options = {
      #   retry_statuses: [429, 403, 404],
      #   max: max_retries,
      #   interval: retry_interval,
      #   retry_block: -> (env, options, retries, exc) { puts "############# retry because #{env.status}" }
      # }

      # retry_options = {
      #   retry_statuses: [429, 403, 404],
      #   max: 2,
      #   interval: 0.5,
      #   interval_randomness: 0.5,
      #   backoff_factor: 2
      # }

      sleep(retry_interval)
      get_data(url, retry_options)
    end

    private

    def get_data(url, retry_options = {})
      connection = Faraday.new(url, headers: headers) do |f|
        f.request :retry, retry_options unless retry_options.blank?
      end
      connection = Faraday.new(url, headers: headers)
      response = connection.get
      raise NotFound.new(error_message(response)) if response.status == 404
      raise NotAllowed.new(error_message(response)) if response.status == 403
      raise ApiFailure.new(error_message(response)) unless response.success?
      JSON.parse(response.body)
    end

    def headers
      { 'Authorization' => @api_key }
    end

    def make_url(mpxn, fuel_type = nil, data_type = nil, element = nil, start_date = nil, end_date = nil)
      url = @base_url
      url += mpxn.to_s + '/' unless mpxn.nil?
      url += fuel_type + '/' unless fuel_type.nil?
      url += data_type + '/' unless data_type.nil?
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
        "#{error['code']} : #{error['message']}"
      else
        response.status
      end
    rescue => e
      e.message
    end

  end
end
