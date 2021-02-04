module MeterReadingsFeeds
  class N3rgyConsentApi
    include Logging

    def initialize(api_key, base_url, debugging)
      @api_key = api_key
      @base_url = base_url
      @debugging = debugging
    end

    def grant_trusted_consent(mpxn, file_link)
      url = base_url + 'consents/add-trusted-consent'
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
      log(response.inspect)
      response
    end

    def withdraw_trusted_consent(mpxn)
      url = base_url + 'consents/withdraw-consent?mpxn=' + mpxn.to_s
      response = Faraday.put(url) do |req|
        req.headers['Authorization'] = @api_key
      end
      log(response.inspect)
      response
    end

    def base_url
      @base_url
    end
  end
end
