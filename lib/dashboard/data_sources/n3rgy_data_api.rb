module MeterReadingsFeeds
  class N3rgyDataApi
    include Logging

    DATA_TYPE_CONSUMPTION = 'consumption'
    DATA_TYPE_TARIFF = 'tariff'
    DATA_TYPE_PRODUCTION = 'production'

    def initialize(api_key, base_url, debugging)
      @api_key = api_key
      @base_url = base_url
      @debugging = debugging
    end

    def get_consumption_data(mpxn: nil, fuel_type: nil, element: 1, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_CONSUMPTION, element, start_date, end_date)
      get_data(url)
    end

    def get_tariff_data(mpxn: nil, fuel_type: nil, element: 1, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_TARIFF, element, start_date, end_date)
      get_data(url)
    end

    def get_production_data(mpxn: nil, fuel_type: nil, element: 1, start_date: nil, end_date: nil)
      url = make_url(mpxn, fuel_type, DATA_TYPE_PRODUCTION, element, start_date, end_date)
      get_data(url)
    end

    private

    def get_data(url)
      connection = Faraday.new(url, headers: headers)
      response = connection.get
      JSON.parse(response.body)
    end

    def headers
      { 'Authorization' => @api_key }
    end

    def base_url
      @base_url
    end

    def make_url(mpxn, fuel_type, data_type, element, start_date, end_date)
      url = base_url
      url += mpxn.to_s + '/' unless mpxn.nil?
      url += fuel_type + '/' unless fuel_type.nil?
      url += data_type + '/' unless data_type.nil?
      url += element.to_s unless element.nil?
      url += half_hourly_query(start_date, end_date) unless start_date.nil? || end_date.nil?
      url
    end

    def half_hourly_query(start_date, end_date)
      '?start=' + url_date(start_date) + '&end=' + url_date(end_date, true) + '&granularity=halfhour'
    end

    def url_date(date, end_date = false)
      end_date ? date.strftime('%Y%m%d2359') : date.strftime('%Y%m%d0000')
    end
  end
end
