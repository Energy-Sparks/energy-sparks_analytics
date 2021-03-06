require_relative '../../lib/dashboard.rb'

api = MeterReadingsFeeds::GeoApi.new(username: ENV['GEO_API_USERNAME'], password: ENV['GEO_API_PASSWORD'])

# token = api.login

token = api.login
pp token

result = api.trigger_fast_update('99a39901-1ca6-4f3d-8b2d-8ad086290352')
pp result

readings = api.live_data('99a39901-1ca6-4f3d-8b2d-8ad086290352')
pp readings

# puts "Token: #{token}"

# api = MeterReadingsFeeds::GeoApi.new(token)
#
# result = api.trigger_fast_update('99a39901-1ca6-4f3d-8b2d-8ad086290352')
# pp result
#
# 5.times do
#   sleep 3
#   readings = api.live_data('99a39901-1ca6-4f3d-8b2d-8ad086290352')
#   # pp readings
#   #
#   puts "Power timestamp: #{readings['powerTimestamp']}"
#   readings['power'].each do |power|
#     puts "#{power['type']} (watts): #{power['watts']}"
#   end
# end
#
# puts 'done'
