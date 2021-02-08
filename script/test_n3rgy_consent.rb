require_relative '../lib/dashboard.rb'

n3rgyConsent = MeterReadingsFeeds::N3rgyConsent.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_CONSENT_BASE_URL'])

mpxn = 2234567891000
example_consent_file_link = 'https://energysparks.uk/meters/2234567891000'

response = n3rgyConsent.grant_trusted_consent(mpxn, example_consent_file_link)
puts response.inspect

response = n3rgyConsent.withdraw_trusted_consent(mpxn)
puts response.inspect
