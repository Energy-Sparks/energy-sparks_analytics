require 'digest'
require 'net/http'
require 'json'
require 'amazing_print'
require 'date'
require 'csv'
require 'faraday'
require_relative '../../lib/dashboard/data_sources/metering/solar_edge/solar_edge_api.rb'

def default_config
  {
    start_date:     Date.today - 5,
    end_date:       Date.today - 1,
    csv_filename:   'solartestfile.csv',
    api_key:        ENV['ENERGYSPARKSSOLAREDGEAPIKEY'],
    site_id:        1508552,
    site_details:   false,
    mpan:           123456789
  }
end

def parse_command_line(config)
  args = ARGV.clone
  ap args
  while !args.empty?
    if args[0] == '-startdate' && args.length >= 2
      config[:start_date] = Date.parse(args[1])
      args.shift(2)
    elsif args[0] == '-enddate' && args.length >= 2
      config[:end_date] = Date.parse(args[1])
      args.shift(2)
    elsif args[0] == '-days' && args.length >= 2
      config[:start_date] = Date.today - args[1].to_i
      config[:end_date]   = Date.today - 1
      args.shift(2)
    elsif args[0] == '-csvfilename' && args.length >= 2
      config[:csv_filename] = args[1]
      args.shift(2)
    elsif args[0] == '-apikey' && args.length >= 2
      config[:api_key] = args[1]
      args.shift(2)
    elsif args[0] == '-mpan' && args.length >= 2
      config[:mpan] = args[1].to_i
      args.shift(2)
    elsif args[0] == '-siteid' && args.length >= 2
      config[:site_id] = args[1]
      args.shift(2)
    elsif args[0] == '-alldays'
      config[:start_date] = nil
      config[:end_date]   = nil
      args.shift(1)
    elsif args[0] == '-printsitedetails'
      config[:site_details] = true
      args.shift(1)
    else
      puts "Unexpected arguments #{args[0]}"
      puts "Arguments: -startdate <date> || -enddate <date> || -alldates "
      puts "        || -apikey <key> || -mpan <mpanroot>"
      puts "        || -siteid <key> || -printsitedetails || -days <N days data>"
      puts "provided arguments:"
      ap ARGV
      break
    end
  end
  config
end

def energy_sparks_solar_mpan(meter_type, mpan)
  case meter_type
  when :electricity
    90000000000000 + mpan
  when :solar_pv
    70000000000000 + mpan
  when :exported_solar_pv
    60000000000000 + mpan
  end
end

def save_readings_to_csv(readings, filename, mpan)
  puts "Saving readings to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['date', 'mpan', 'meter type', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings.each do |meter_type, data|
      data[:readings].each do |date, kwh_x48|
        es_mpan = energy_sparks_solar_mpan(meter_type, mpan)
        csv << [date, es_mpan, meter_type, kwh_x48.sum, kwh_x48].flatten
      end
    end
  end
end

def process_on_meter_set(config)
  puts "=" * 80
  puts "Config:"
  ap config
  solar_edge = SolarEdgeSolarPV.new(config[:api_key])

  puts "Site details:"
  if config[:site_id]
    ap site_details
    ap site_ids
  else
    puts "No site details"
  end

  readings = solar_edge.smart_meter_data(config[:site_id], config[:start_date], config[:end_date])

  save_readings_to_csv(readings, config[:csv_filename], config[:mpan])

  puts "Missing readings:"
  readings.values.each do |data|
    ap data[:missing_readings] unless data[:missing_readings].empty?
  end
rescue => e
  puts "Download failed"
  puts e.message
  puts e.backtrace
end

def process_file(filename)
  puts "Processing config file #{filename}"
  configs = CSV.read(filename)
  configs.each do |config|
    c = {
      csv_filename: "Results/#{config[0]} solar edge.csv",
      api_key:      config[1],
      site_id:      config[2].nil? ? nil: config[2].to_i,
      start_date:   config[3].nil? ? nil : Date.parse(config[3]),
      end_date:     Date.today - 1,
      mpan:         config[4].nil? ? nil: config[4].to_i,
    }
    process_on_meter_set(c)
  end
end

def bulk_process(args)
  ap args
  index = args.index('-configfile')
  process_file(args[index+1])
end

if ARGV.include?('-configfile')
  bulk_process(ARGV)
else
  config = parse_command_line(default_config)
  process_on_meter_set(config)
end
