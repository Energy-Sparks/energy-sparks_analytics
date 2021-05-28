require_relative '../../lib/dashboard.rb'

token = MeterReadingsFeeds::GeoApi.new(username: ENV['GEO_API_USERNAME'], password: ENV['GEO_API_PASSWORD']).login

# puts "Token: #{token}"

def convert_time_stamps(hash)
  return unless hash.is_a?(Hash)
  hash.each do |k, v|
    if k == "readingTime" || k.include?('Timestamp') ||
        k.include?('UTC') || k.include?('timeOfChange') ||
        k.include?('Utc') || k.include?('StartTime') ||
        k.include?('budgetToC') || k.include?('utc')
      hash[k] = Time.at(v).to_datetime.strftime('%d %b %Y %H:%M')
    elsif v.is_a?(Hash)
      v.each do |kk, vv|
        convert_time_stamps(vv)
      end
    elsif v.is_a?(Array)
      v.each do |vv|
        convert_time_stamps(vv)
      end
    else
      # no nothing
    end
  end
end

def process_epochs(result)
  kwhs = result['values'].map do |epoch|
    energy = epoch['epochEnergies']
    import = energy.select { |v| v['energyType'] == 'IMPORT' }[0]
    import['energyKWh'].to_f
  end
  total_kwh = kwhs.sum
  puts "Total kWh #{total_kwh}"
  total_kwh
end

def process_period_data(result)
  pp result.keys
  day = result['currentCostsElec'].select { |v| v['duration'] == 'DAY' && v['commodityType'] == 'ELECTRICITY' }
  day[0]['energyAmount']
end

system_id = '99a39901-1ca6-4f3d-8b2d-8ad086290352'

puts
puts "=" * 80
puts "Live Data"

api = MeterReadingsFeeds::GeoApi.new(token: token)
result = api.trigger_fast_update(system_id)
pp result
sleep 3
result = api.live_data(system_id)
pp convert_time_stamps(result)

puts "=" * 80
puts "Periodic Data"
result = api.periodic_data(system_id)
pp convert_time_stamps(result)
day_kwh = process_period_data(result)

puts "=" * 80
puts "Daily Data"
result = api.daily_data(system_id)
pp convert_time_stamps(result)

puts "=" * 80
puts "Historic Day"
result = api.historic_day(system_id, Date.new(2021, 5, 26), Date.new(2021, 5, 28))
pp result
pp convert_time_stamps(result)

puts "=" * 80
puts "Historic Week"
result = api.historic_week(system_id, Date.new(2021, 5, 12), Date.new(2021, 5, 26))
pp result
pp convert_time_stamps(result)

puts "=" * 80
puts "Historic Month"
result = api.historic_month(system_id, 11, 2020, 5, 2021)
pp result
pp convert_time_stamps(result)

puts "=" * 80
puts "Epochs"
result = api.epochs(system_id, Date.new(2021, 5, 27), Date.new(2021, 5, 27))
pp convert_time_stamps(result)
epoch_day_kwh = process_epochs(result)
puts "Total period day #{day_kwh} epoch day kwh #{epoch_day_kwh}"
=begin
puts "=" * 80
puts "Summaries"
result = api.summaries(system_id, Date.new(2021, 3, 26), Date.new(2021, 5, 26))
pp result
pp convert_time_stamps(result)
=end


exit

result = api.trigger_fast_update(system_id)
pp result

5.times do
  sleep 3
  readings = api.live_data(system_id)
  # pp readings
  #
  puts "Power timestamp: #{readings['powerTimestamp']}"
  readings['power'].each do |power|
    puts "#{power['type']} (watts): #{power['watts']}"
  end
end

puts 'done'
