module MeterReadingsFeeds
  class N3rgyConsent

    def initialize(api_key:, base_url:)
      @api_key = api_key
      @base_url = base_url
    end

    def grant_trusted_consent(mpxn, reference)
      api.grant_trusted_consent(mpxn, reference)
      true
    end

    def withdraw_trusted_consent(mpxn)
      api.withdraw_trusted_consent(mpxn)
      true
    end

    def api
      raise MissingConfig.new("Apikey must be set") unless @api_key.present?
      raise MissingConfig.new("Base URL must be set") unless @base_url.present?
      @api ||= N3rgyConsentApi.new(@api_key, @base_url)
    end
  end
end
