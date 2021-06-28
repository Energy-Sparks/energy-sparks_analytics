require 'date'
require 'logger'

require 'require_all'
require_relative '../../lib/dashboard.rb'

def rbee
  @rbee ||= RbeeSolarPV.new
end

def full_install_info(meter_id)
  rbee.full_installation_information(meter_id)
end

def meter_data(meter_id, start_date, end_date)
  # rbee_connection.full_installation_information(meter_id)
  rbee.smart_meter_data_debug(meter_id, start_date, end_date)
end

def all_meter_data(start_date, end_date)
  meter_ids = rbee.available_meter_ids
  meters_data(meter_ids, start_date, end_date)
end

def meters_data(meter_ids, start_date, end_date)
  meter_ids.each do |meter_id|
    puts '=' * 80
    puts "meter id: #{meter_id}"
    meter_data(meter_id, start_date, end_date)
  end
end

def save_to_csv(results)
  data_keys = results.map { |data| data[:readings].keys }.flatten.uniq
  CSV.open('Results\joju.csv', 'w') do |csv|
    csv << ['postcode', 'name', 'kwp', 'first date', data_keys].flatten
    results.each do |data|
      kwhs = data_keys.map { |k| data[:readings][k] }
      csv << [data[:postcode], data[:name], data[:kwp], data[:start_date], kwhs].flatten
    end
  end
end

puts "User:     #{ENV['ENERGYSPARKSRBEEUSERNAME']}"
puts "Password: #{ENV['ENERGYSPARKSRBEEPASSWORD']}"

start_date = nil # Date.new(2021, 6, 1)
end_date   = Date.new(2021, 6, 1)

if true
  meter_ids = [
    219207160,
    219207157,
    219011104
  ]
  
  meter_ids = rbee.available_meter_ids

  puts "Processing #{meter_ids.length} meters"

  i = 0

  results = []

  meter_ids.each do |meter_id|
    info = full_install_info(meter_id)
    result = {
      name:       info['installationName'],
      postcode:   info['zipCode'],
      start_date: info['firstConnectionDate'],
      kwp:        info['peakPower'],
      readings:   meter_data(meter_id, start_date, end_date)
    }
    ap result
    results.push(result)
    i += 1
    break if i == 2000
  end
  ap results
  save_to_csv(results)
else
  all_meter_data(start_date, end_date)
end
