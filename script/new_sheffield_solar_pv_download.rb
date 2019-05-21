require 'require_all'
require_relative '../lib/dashboard.rb'
require_relative './csv_file_support.rb'

module Logging
  @logger = Logger.new('log/download sheffield pv data' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def report_bad_data(missing_date_times, whole_day_substitutes)
  if missing_date_times.empty?
    puts 'No missing data'
  else
    puts "#{missing_date_times.length} missing items of data:"
    missing_date_times.each_slice(6) do |one_row|
      formatted_datetimes  = one_row.map { |dt| dt.strftime('%Y%b%d %H:%M') }
      puts "#{formatted_datetimes.join(' ')}"
    end
    unless whole_day_substitutes.empty?
      whole_day_substitutes.each do |missing_date, substitute_date|
        puts "Warning: not enough data on #{missing_date.strftime('%Y%b%d')} substituted from #{substitute_date.strftime('%Y%b%d')}"
      end
    end
  end
end

def sum_pv_data(date_to_x48)
  date_to_x48.values.flatten(1).sum
end

@v1_climate_zones = {    # probably not the same climate zones as the other inputs, more critical they are local, so schools to west of Bath may need their own 'climate zone'
  'Bath' => { latitude: 51.39,
              longitude: -2.37,
              proxies: [
                          { id: 152, name: 'Iron Acton', code: 'IROA', latitude: 51.56933, longitude: -2.47937 },
                          { id: 198, name: 'Melksham', code: 'MELK', latitude: 51.39403, longitude: -2.14938 },
                          { id: 253, name: 'Seabank', code: 'SEAB', latitude: 51.53663, longitude: -2.66869 }
                        ],
              filename: 'pv data Bath.csv'
  }
}

def csv_file(filename, datum_for_feed)
  start_date = datum_for_feed
  file = TestCSVFileSupport.new(filename)
  if file.exists?
    file.backup
    start_date = file.last_reading_date
  end
  [file, start_date]
end

def old_pv_feed
  # ================= old V1 pre May 2019 interface =================================
  bath_config = @v1_climate_zones['Bath']

  v1_pv_interface = SheffieldSolarPVV1.new(bath_config[:latitude], bath_config[:longitude], bath_config[:proxies])

  # datetimes[date] = solar_pv_yields[x48] - date hash to array of 48 half hourly yield
  # n.b. 'Bath' or area name only passed in for debugging purposes
  pv_data_dates_to_x48 = v1_pv_interface.download_historic_solar_pv_data('Bath', start_date, end_date)

  puts "Total yield #{sum_pv_data(pv_data_dates_to_x48)}"

  # ap(pv_data_date_to_x48)
end

def update_solar_pv_csv_file(filename, name, latitude, longitude, datum_for_feed, end_date)
  puts '=' * 80
  puts "Updating solar pv for #{name}"

  file, start_date = csv_file(filename, datum_for_feed)

  if start_date >= end_date
    puts 'PV data up to date'
    return
  end

  pv_interface = SheffieldSolarPVV2.new

  nearest = pv_interface.find_nearest_areas(latitude, longitude)

  puts '5 nearest solar pv areas'
  ap(nearest)

  solar_pv_data, missing_date_times, whole_day_substitutes = pv_interface.historic_solar_pv_data(nearest.first[:gsp_id], latitude, longitude, start_date, end_date)

  puts "Total yield #{sum_pv_data(solar_pv_data)}"

  file.append_lines_and_close(solar_pv_data)

  report_bad_data(missing_date_times, whole_day_substitutes)
end

=begin
latitude = 51.60728
longitude = -2.00116

pv_interface = SheffieldSolarPVV2.new

nearest = pv_interface.find_nearest_areas(latitude, longitude)

puts '5 nearest solar pv areas'
ap(nearest)

start_date = Date.new(2014, 1, 1)
end_date = Date.new(2019, 5, 18)

solar_pv_data, missing_date_times, whole_day_substitutes = pv_interface.historic_solar_pv_data(nearest.first[:gsp_id], latitude, longitude, start_date, end_date)

puts 'Missing dates'
ap(missing_date_times)
puts 'whole days'
ap(whole_day_substitutes)
exit
=end

# =================== MAIN ============================
datum_for_feed = Date.new(2014, 1, 1)
end_date = Date.today - 1

AreaNames::AREA_NAMES.each do |_area, location_data|
  update_solar_pv_csv_file(
    location_data[:solar_pv_filename],
    location_data[:name],
    location_data[:latitude],
    location_data[:longitude],
    datum_for_feed,
    end_date
  )
end
