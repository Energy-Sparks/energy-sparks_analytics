module MeterReadingsFeeds
  class N3rgyConsentApi
    include Logging

    class ConsentFailed < StandardError; end

    def initialize(api_key, base_url)
      @api_key = api_key
      @base_url = base_url
    end

    def grant_trusted_consent(mpxn, reference)
      url = base_url + 'consents/add-trusted-consent'
      config = {
        'mpxn'        => mpxn.to_s,
        'apiKey'      => @api_key,
        'evidence'    => reference,
        'moveInDate'  => '2012-01-01'
      }
      response = Faraday.post(url) do |req|
        req.headers['Authorization'] = @api_key
        req.body = config.to_json
      end
      raise ConsentFailed, error_message(response) unless response.success?
      JSON.parse(response.body)
    end

    def withdraw_trusted_consent(mpxn)
      url = base_url + 'consents/withdraw-consent?mpxn=' + mpxn.to_s
      response = Faraday.put(url) do |req|
        req.headers['Authorization'] = @api_key
      end
      raise ConsentFailed.new(error_message(response)) unless response.success?
      true
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
      response.body
    end

    def base_url
      @base_url
    end
  end
end
