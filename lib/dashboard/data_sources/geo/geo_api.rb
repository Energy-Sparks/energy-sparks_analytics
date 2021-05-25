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
  end
end
