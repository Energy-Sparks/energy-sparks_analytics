require_relative '../../lib/dashboard.rb'

# for live
n3rgyData = MeterReadingsFeeds::N3rgyData.new(api_key: ENV['N3RGY_API_KEY'], base_url: ENV['N3RGY_DATA_URL'])

# for sandbox
# n3rgyData = MeterReadingsFeeds::N3rgyData.new(api_key: ENV['N3RGY_SANDBOX_API_KEY'], base_url: ENV['N3RGY_SANDBOX_DATA_URL'], bad_electricity_standing_charge_units: true)

# good sandbox mpan
# mpxn = 2234567891000

# bad sandbox mpan
# mpxn = 9234567891000

# mpxn = 1234567891000
# mpxn = 2234567891001
mpxn = 3985185808
# mpxn = 9234567891000
# mpxn = 2200015678553
# mpxn = 1100000000001

# fuel_type = :electricity
fuel_type = :gas
start_date = Date.parse('20210510')
end_date = Date.parse('20210510')

# readings = n3rgyData.readings(mpxn, fuel_type, start_date, end_date)
# pp readings.inspect

readings = n3rgyData.tariffs(mpxn, fuel_type, start_date, end_date)
pp readings.inspect

# status = n3rgyData.status(mpxn)
# pp status.inspect

# response = n3rgyData.find(mpxn)
# pp response.inspect
#
# resp = n3rgyData.inventory(mpxn)
# puts resp

# resp = n3rgyData.list
# puts resp

# resp = n3rgyData.cache_start_datetime(mpxn: mpxn, fuel_type: fuel_type)
# puts resp


# resp = n3rgyData.readings_available_date_range(mpxn, fuel_type)
# puts resp

# resp = n3rgyData.tariffs_available_date_range(mpxn, fuel_type)
# puts resp

# puts "start date is #{resp.first} (class #{resp.first.class})"
# puts "start date is #{resp.last}"
