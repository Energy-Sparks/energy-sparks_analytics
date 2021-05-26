module MeterReadingsFeeds
  class GeoApi
    include Logging

    class ApiFailure < StandardError; end
    class NotFound < StandardError; end
    class NotAllowed < StandardError; end
    class NotAuthorised < StandardError; end

    BASE_URL = 'https://api.geotogether.com/api'

    def initialize(token, connection=nil)
      @token = token
      @connection = connection
    end

    def self.login(username, password)
      payload = { emailAddress: username, password: password }
      response = Faraday.post(BASE_URL + '/userapi/account/login', payload.to_json, headers)
      ret = handle_response(response)
      ret['token']
    end

    def trigger_fast_update(systemId)
      response = Faraday.get(BASE_URL + '/supportapi/system/trigger-fastupdate/' + systemId, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def live_data(systemId)
      response = Faraday.get(BASE_URL + '/supportapi/system/smets2-live-data/' + systemId, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def periodic_data(systemId)
      response = Faraday.get(BASE_URL + '/supportapi/system/smets2-periodic-data/' + systemId, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def daily_data(systemId)
      response = Faraday.get(BASE_URL + '/supportapi/system/smets2-daily-data/' + systemId, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def historic_day(systemId, start_date, end_date)
      url = "/supportapi/system/smets2-historic-day/#{systemId}?from=#{utc_date(start_date)}&to=#{utc_date(end_date)}"
      response = Faraday.get(BASE_URL + url, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def historic_week(systemId, start_date, end_date)
      url = "/supportapi/system/smets2-historic-week/#{systemId}?from=#{utc_date(start_date)}&to=#{utc_date(end_date)}"
      response = Faraday.get(BASE_URL + url, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def historic_month(systemId, from_month, from_year, to_month, to_year)
      url = "/supportapi/system/smets2-historic-month/#{systemId}?fromMonth=#{from_month}&fromYear=#{from_year}&toMonth=#{to_month}&toYear=#{to_year}"
      response = Faraday.get(BASE_URL + url, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def epochs(systemId, start_date, end_date)
      url = "/supportapi/system/epochs/#{systemId}?from=#{utc_date(start_date)}&to=#{utc_date(end_date)}"
      puts url
      response = Faraday.get(BASE_URL + url, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def summaries(systemId, start_date, end_date)
      url = "/supportapi/system/summaries/#{systemId}?from=#{utc_date(start_date)}&to=#{utc_date(end_date)}"
      response = Faraday.get(BASE_URL + url, nil, self.class.headers(@token))
      self.class.handle_response(response)
    end

    def self.headers(token = nil)
      hdr = { Accept: 'application/json', 'Content-Type': 'application/json' }
      hdr.merge!({Authorization: "Bearer #{token}"}) if token
      hdr
    end

    def self.handle_response(response)
      raise NotAuthorised.new(error_message(response)) if response.status == 401
      raise NotAllowed.new(error_message(response)) if response.status == 403
      raise NotFound.new(error_message(response)) if response.status == 404
      raise ApiFailure.new(error_message(response)) unless response.success?
      JSON.parse(response.body)
    rescue => e
      #problem parsing or traversing json, return original body
      response.body
    end

    def self.error_message(response)
      data = JSON.parse(response.body)
      if data['reason']
        data['reason']
      elseif data['error']
        data['error']
      else
        response.body
      end
    rescue => e
      #problem parsing or traversing json, return original api error
      response.body
    end

    private

    def utc_date(date)
      date.strftime('%Y-%m-%d')
    end
  end
end
