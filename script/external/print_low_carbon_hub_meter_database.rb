require 'date'
require 'logger'

require 'require_all'
require_relative '../lib/dashboard.rb'
require_relative '../test_support/csv_file_support.rb'

def print_all_available_meter_data
  rbee = RbeeSolarPV.new
  list = rbee.available_meter_ids
  list.each do |meter_id|
    puts '=' * 80
    ap rbee.full_installation_information(meter_id)
  end
end

print_all_available_meter_data
