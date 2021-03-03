require_relative '../lib/dashboard.rb'

# for live
# n3rgyConsent = MeterReadingsFeeds::N3rgyConsent.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_CONSENT_URL'])

# for sandbox
n3rgyConsent = MeterReadingsFeeds::N3rgyConsent.new(api_key: ENV['N3RGY_SANDBOX_API_KEY'], base_url: ENV['N3RGY_SANDBOX_CONSENT_URL'])

mpxn = 2234567891000
example_consent_reference = mpxn.to_s

response = n3rgyConsent.withdraw_trusted_consent(mpxn)
puts response.inspect

response = n3rgyConsent.grant_trusted_consent(mpxn, example_consent_reference)
puts response.inspect

