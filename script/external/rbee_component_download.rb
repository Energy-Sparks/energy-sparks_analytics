require 'date'
require 'logger'

require 'require_all'
require_relative '../../lib/dashboard.rb'

def rbee
  @rbee ||= RbeeSolarPV.new
end

def save_to_csv(meter_id, type, readings)
  filename = "Results\\rbee #{meter_id} #{type}.csv"
  puts "Saving to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['date', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings.each do |date, kwh_x48|
      csv << [date, kwh_x48].flatten
    end
  end
end

puts "User:     #{ENV['ENERGYSPARKSRBEEUSERNAME']}"
puts "Password: #{ENV['ENERGYSPARKSRBEEPASSWORD']}"

start_date = Date.new(2021, 6, 1)
end_date   = Date.new(2021, 6, 2)
meter_id = 219207160
type = 'prod'

data = rbee.smart_meter_data_by_component(meter_id, start_date, end_date, type)

ap data

save_to_csv(meter_id, type, data[:readings])
