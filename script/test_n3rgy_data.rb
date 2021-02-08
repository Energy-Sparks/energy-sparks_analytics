require_relative '../lib/dashboard.rb'

logging = { puts: true, ap: { limit: false } }

n3rgyData = MeterReadingsFeeds::N3rgyData.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_DATA_BASE_URL'], debugging: logging)

mpxn = 2234567891000
fuel_type = :electricity
start_date = Date.parse('01/01/2019')
end_date = Date.parse('02/01/2019')

readings = n3rgyData.readings(mpxn, fuel_type, start_date, end_date)
pp readings.inspect

# readings = n3rgyData.tariffs(mpxn, fuel_type, start_date, end_date)
# pp readings.inspect

# status = n3rgyData.status(mpxn)
# pp status.inspect

# resp = n3rgyData.inventory(mpxn)
# puts resp
