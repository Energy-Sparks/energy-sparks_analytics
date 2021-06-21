require 'date'
require 'logger'

require 'require_all'
require_relative '../../lib/dashboard.rb'

def print_all_available_meter_data
  rbee = RbeeSolarPV.new
  list = rbee.available_meter_ids
  list.each do |meter_id|
    puts '=' * 80
    ap rbee.full_installation_information(meter_id)
  end
end

puts "User:     #{ENV['ENERGYSPARKSRBEEUSERNAME']}"
puts "Password: #{ENV['ENERGYSPARKSRBEEPASSWORD']}"

print_all_available_meter_data
