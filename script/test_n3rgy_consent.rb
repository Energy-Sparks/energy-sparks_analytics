require_relative '../lib/dashboard.rb'

logging = { puts: true, ap: { limit: false } }

n3rgyConsent = MeterReadingsFeeds::N3rgyConsent.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_CONSENT_BASE_URL'], debugging: logging)

example_consent_file_link = 'https://energysparks.uk/meters/2234567891000'
n3rgyConsent.grant_trusted_consent(2234567891000, example_consent_file_link)

