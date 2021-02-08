module MeterReadingsFeeds
  class N3rgyConsent

    # N3RGY_CONSENT_BASE_URL : 'https://consent.data.n3rgy.com/' or 'https://consentsandbox.data.n3rgy.com/'

    def initialize(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_CONSENT_BASE_URL'])
      @api_key = api_key
      @base_url = base_url
    end

    def grant_trusted_consent(mpxn, file_link)
      api.grant_trusted_consent(mpxn, file_link)
      true
    end

    def withdraw_trusted_consent(mpxn)
      api.withdraw_trusted_consent(mpxn)
      true
    end

    def api
      @api ||= N3rgyConsentApi.new(@api_key, @base_url)
    end
  end
end
