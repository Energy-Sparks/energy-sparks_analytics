require_relative '../lib/dashboard.rb'

n3rgyData = MeterReadingsFeeds::N3rgyData.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_DATA_BASE_URL'])

# mpxn = 2234567891000
# mpxn = 1234567891000
mpxn = 9234567891000

fuel_type = :electricity
start_date = Date.parse('20190101')
end_date = Date.parse('20190102')

readings = n3rgyData.readings(mpxn, fuel_type, start_date, end_date)
pp readings.inspect

# readings = n3rgyData.tariffs(mpxn, fuel_type, start_date, end_date)
# pp readings.inspect

# status = n3rgyData.status(mpxn)
# pp status.inspect

# resp = n3rgyData.inventory(mpxn)
# puts resp
