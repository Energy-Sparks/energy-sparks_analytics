require 'date'
require 'open-uri'
require 'require_all'
require 'sun_times'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

require 'uri'
require 'net/http'

# WEATHER UNDERGROUND TEMPERATURE AND SOLAR DATA LOADER
#
# loads temperature and weather data from Weather Underground via a URL
# - data for non-commercial , as per wu licensing
# - tries to minimise the number of URL requests
# - attempts to deal with bad data heuristically
# - averages (& discards) data from a number of weather stations
# - probably best run with end_date set at least 2 hours before run time, as
#   application automatically attempts to get data one day before and one day after requested range
#   to allow for interpolation at start and end of period
#
# I can't work out what half the lint errors in this program mean, so am commenting out the whole lot
# rubocop:disable all
INPUT_DATA_DIR = File.join(File.dirname(__FILE__), '../InputData')

@num_threads = 1
@use_cache = false
@debug_start_date = nil
@debug_end_date = nil

@areas = [
  {
    name: 'Bath',
    latitude: 51.39,
    longitude: -2.37,
    start_date:  Date.new(2018, 9, 26), # may be better in controlling program
    end_date: Date.new(2018, 10, 21), # ditto, inclusive
    method:    :weighted_average,
    max_minutes_between_samples: 120, # ignore data where samples from station are too far apart
    max_temperature: 38.0,
    min_temperature: -15.0,
    solar_scale_factor: 1.0,          # scale solar if necessary if snensors provide different metric
    max_solar_insolence: 2000.0,
    weather_stations_for_temperature:
    { # weight for averaging, selection: the weather station names are found by browsing weather underground local station data
      'ISOMERSE15'  => 0.5,
      'IBRISTOL11'  => 0.2,
      'ISOUTHGL2'   => 0.1,
 #     'IENGLAND120' => 0.1,
      'IBATH9'      => 0.1,
      'IBASTWER2'   => 0.1,
      'ISWAINSW2'   => 0.1,
      'IBASMIDF2'   => 0.1
    },
    weather_stations_for_solar: # has to be a temperature station for the moment - saves loading twice
    {
      'ISOMERSE15' => 0.5
    },
    temperature_csv_file_name: 'Bath temperaturedata.csv',
    solar_csv_file_name: 'Bath solardata.csv',
    csv_format: :landscape
  },
  {
    name: 'Sheffield',
    latitude: 53.3811,
    longitude: -1.4701,
    start_date:  Date.new(2013, 1, 1), # may be better in controlling program
    end_date: Date.new(2018, 9, 25), # ditto, inclusive
    method:    :weighted_average,
    max_minutes_between_samples: 120, # ignore data where samples from station are too far apart
    max_temperature: 38.0,
    min_temperature: -15.0,
    solar_scale_factor: 1.32,
    max_solar_insolence: 2000.0,
    weather_stations_for_temperature:
    { # weight for averaging, selection: the weather station names are found by browsing weather underground local station data
      'ISHEFFIE84'  => 0.1,
      'ISHEFFIE18'  => 0.25,
      'ISOUTHYO31'  => 0.3,
      'ISOUTHYO29'  => 0.1,
      'ISHEFFIE56'  => 0.25
    },
    weather_stations_for_solar: # has to be a temperature station for the moment - saves loading twice
    {
      'ISHEFFIE18' => 0.33,
      'ISOUTHYO31' => 0.33,
      'ISHEFFIE56' => 0.33
    },
    temperature_csv_file_name: 'Sheffield temperaturedata.csv',
    solar_csv_file_name: 'Sheffield solardata.csv',
    csv_format: :landscape
  },
  {
    name: 'Frome',
    latitude: 51.2308,
    longitude: -2.3201,
    start_date:  Date.new(2013, 8, 12), # may be better in controlling program
    end_date: Date.new(2018, 9, 26), # ditto, inclusive
    method:    :weighted_average,
    max_minutes_between_samples: 120, # ignore data where samples from station are too far apart
    max_temperature: 38.0,
    min_temperature: -15.0,
    solar_scale_factor: 1.0,
    max_solar_insolence: 2000.0,
    weather_stations_for_temperature:
    { # weight for averaging, selection: the weather station names are found by browsing weather underground local station data    
      'IFROME9'   => 0.25,
      'IFROME5'   => 0.25,
      'IWARMINS4' => 0.1,
      'IWILTSHI36'=> 0.1,
      'IRADSTOC7' => 0.1,
      'IKILMERS2' => 0.1,
      'IUPTONNO2' => 0.1
    },
    weather_stations_for_solar: # has to be a temperature station for the moment - saves loading twice
    {
      'IKILMERS2' => 0.5,
      'IUPTONNO2' => 0.5
    },
    temperature_csv_file_name: 'Frome temperaturedata.csv',
    solar_csv_file_name: 'Frome solardata.csv',
    csv_format: :landscape
  },
  {
    name: 'Bristol',
    latitude: 51.4545,
    longitude: -2.5879,
    start_date:  Date.new(2010, 1, 1), # may be better in controlling program
    end_date: Date.new(2018, 9, 26), # ditto, inclusive
    method:    :weighted_average,
    max_minutes_between_samples: 120, # ignore data where samples from station are too far apart
    max_temperature: 38.0,
    min_temperature: -15.0,
    solar_scale_factor: 1.32,
    max_solar_insolence: 2000.0,
    weather_stations_for_temperature:
    { # weight for averaging, selection: the weather station names are found by browsing weather underground local station data    
      'IBRISTOL157' => 0.09,
      'IENGLAND726' => 0.09,
      'IGREATER82' => 0.09,
      'IBRISTOL11' => 0.09,
      'IGREATER86' => 0.09,
      'IGREATER93' => 0.09,
      'IBRISTOL30' => 0.09,
      'IBRISTOL137' => 0.09,
      'IBRISTOL25' => 0.09,
      'IBRISTOL151' => 0.09,
      'IBRISTOL15' => 0.09,
      'ISOMERSE15' => 0.0001    # Bath station to help with solar history
    },
    weather_stations_for_solar: # has to be a temperature station for the moment - saves loading twice
    {
      'IGREATER82' => 0.25,
      'IBRISTOL11' => 0.25,
      'IGREATER93' => 0.25,
      'ISOMERSE15' => 0.25    # Bath station to help with history
    },
    temperature_csv_file_name: 'Bristol temperaturedata.csv',
    solar_csv_file_name: 'Bristol solardata.csv',
    csv_format: :landscape
  }
]

def generate_single_day_station_history_url(station_name, date)
  sprintf(
    "https://www.wunderground.com/weatherstation/WXDailyHistory.asp?ID=%s&year=%d&month=%d&day=%d&graphspan=day&format=1",
    station_name,
    date.year,
    date.month,
    date.day)
end

# check for sunrise (margin = hours after sunrise, before sunset test applied)
def daytime?(datetime, latitude, longitude, margin_hours = 0)
  sun_times = SunTimes.new

  sunrise = sun_times.rise(datetime, latitude, longitude)
  sr_criteria = sunrise + 60 * 60 * margin_hours
  sr_criteria_dt = DateTime.parse(sr_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

  sunset = sun_times.set(datetime, latitude, longitude)
  ss_criteria = sunset - 60 * 60 * margin_hours
  ss_criteria_dt = DateTime.parse(ss_criteria.to_s) # crudely convert to datetime, avoid time as very slow on Windows

  datetime > sr_criteria_dt && datetime < ss_criteria_dt
end

def cache_filename(station_name, date)
  INPUT_DATA_DIR + '/Cache/' + station_name + ' - ' + date.strftime('%Y %m %d') + '.txt'
end

def download_one_day(station_name, date, max_temp, min_temp, max_solar)
  data = {}
  header = []
  lines = nil
  got_file = false
  if @use_cache
    begin
      lines = File.read(cache_filename(station_name, date))
      got_file = true
    rescue Exception
      lines = nil
    end
  end

  if lines.nil?
    url = generate_single_day_station_history_url(station_name, date)
    puts "Downloading #{date} #{station_name} #{url}"

    lines = download_one_page(station_name, date)

    if @use_cache and !got_file
      File.write(cache_filename(station_name, date), lines)
    end
  end

  if !@debug_start_date.nil? && date >= @debug_start_date && date <= @debug_end_date
    puts "Raw data for #{station_name} #{date}"
    puts lines
  end

  unless lines.nil?
    lines = lines.split('<br>')
    line_num = 0
    lines.each do |line|
      line = line.strip
      # puts line
      line_components = line.split(',')
      next if line_components.length < 5
      if line_num == 0
        header = line_components
      else     
        datetime, temperature, solar_value = extract_temperature_and_solar_data_from_line(line_components, header,  max_temp, min_temp, max_solar)
        
        if !temperature.nil? && temperature <= max_temp && temperature >= min_temp  # only use data if the temperature is within range
          data[datetime] = [temperature, solar_value]
        end
      end
      line_num += 1
    end
  else
    puts "request failed"
    puts res.code
  end 
  # puts "Avg temp #{average_temperature(data)} on #{date}"
  data # one days data
end

def download_one_page(station_name, date)
  url = generate_single_day_station_history_url(station_name, date)

  res = Net::HTTP.get_response(URI(url))

  if res.is_a?(Net::HTTPSuccess)
    # puts res.body
    return res.body
  else
    puts "request failed"
    puts res.code
  end 
  nil
end

def download_one_day_old(station_name, date, max_temp, min_temp, max_solar)
  puts "Downloading #{date} #{station_name}"
  data = {}
  url = generate_single_day_station_history_url(station_name, date)
  puts "HTTP request for                     #{url}"
  header = []
  web_page = open(url){ |f|
    line_num = 0
    f.each_line do |line|
      line = line.strip
      line_components = line.split(',')
      if line_num == 1
        header = line_components
      elsif line_components.length > 2 # ideally I should use an encoding which ignores the <br> line ending coming in as a single line
        
        datetime, temperature, solar_value = extract_temperature_and_solar_data_from_line(line_components, header,  max_temp, min_temp, max_solar)
        
        if !temperature.nil? && temperature <= max_temp && temperature >= min_temp  # only use data if the temperature is within range
          data[datetime] = [temperature, solar_value]
        end
      end
      line_num += 1
    end
  }
  puts "Avg temp #{average_temperature(data)} on #{date}"
  data # one days data
end

def average_temperature(data)
  total_temperatures = 0
  count = 0
  data.each do |dt, temp_solar|
    total_temperatures += temp_solar[0]
    count += 1
  end
  count == 0 ? 0 : (total_temperatures / count)
end

def extract_temperature_and_solar_data_from_line(line_components, header,  max_temp, min_temp, max_solar)
    useFarenheit = false
    temperature_index = header.index('TemperatureC')
    if temperature_index.nil? && !header.index('TemperatureF').nil?
      useFarenheit = true
      temperature_index = header.index('TemperatureF')
    end
    solar_index = header.index('SolarRadiationWatts/m^2')
    datetime = DateTime.parse(line_components[0])
    temperature = !line_components[temperature_index].nil? ? line_components[temperature_index].to_f : nil
    temperature = (temperature -32) * 5.0 / 9.0 if useFarenheit
    solar_string = solar_index.nil? ? nil : line_components[solar_index]
    solar_value = solar_string.nil? ? nil : solar_string.to_f
    solar_value = solar_value.nil? ? nil : (solar_value < max_solar ? solar_value : nil)
    [datetime, temperature, solar_value]
end


# get raw data one day/webpage at a time, data is on random minute boundaries, so not suitable for direct use
def get_raw_temperature_and_solar_data(station_name, start_date, end_date, max_temp, min_temp, max_solar)
  puts "Getting data for #{station_name} between #{start_date} and #{end_date}"
  data = {}

  # create queue of requests
  @queue = []
  (start_date..end_date).each do |date|
    @queue.push([station_name, date, max_temp, min_temp, max_solar])
  end

  #process queue
  if @num_threads > 1
    @lock = Mutex.new
    @threads = Array.new(@num_threads) do
      Thread.new do
        until @queue.empty?
          station_name, date, max_temp, min_temp, max_solar = @queue.shift
          one_days_data = download_one_day(station_name, date, max_temp, min_temp, max_solar)
          Thread.current['data'] = [] if !Thread.current.key?('data')
          Thread.current['data'].push([date,one_days_data])
          # @lock.synchronize {
          #   data[date]= [date, one_days_data]
          #}
        end
      end
    end

    # @threads.each(&:join)
    @threads.each do |t|
      t.join
      t['data'].each do |dtd|
        data[dtd[0]] = dtd[1] if !dtd.empty?
        # puts "Avg temp X #{average_temperature(dtd[1])} on #{dtd[0]}"
      end
    end
  else
    until @queue.empty?
      station_name, date, max_temp, min_temp, max_solar = @queue.shift
      one_days_data = download_one_day(station_name, date, max_temp, min_temp, max_solar)
      data[date] = one_days_data
    end
  end

  # unpack data by date into a single datetime hashed hash
  station_data = {}
  data = data.sort.to_h
  data.each_value do |days_data|
    days_data.each do |dt, vals|
      station_data[dt] = vals
    end
    # puts "Avg temp Y #{average_temperature(days_data)}"
  end
  puts "got #{station_data.length} observations"
  assess_data(station_name, station_data, start_date, end_date)
  station_data
end

def assess_data(station_name, data, start_date, end_date)
  puts "Assessing data between #{start_date} and #{end_date} for #{data.length} observations"
  date_count = {}
  data.each do |dt, _one_sample|
    date = Date.new(dt.year, dt.month, dt.day)
    date_count[date] = 0 if !date_count.key?(date)
    date_count[date] += 1
  end
  missing_dates = []
  too_low_date_count = []
  (start_date..end_date).each do |date|
    if date_count.key?(date)
      too_low_date_count.push(date) if date_count[date] < 12
    else
      missing_dates.push(date)
    end
  end
  puts "Missing Dates:"
  cpmd = CompactDatePrint.new(missing_dates)
  cpmd.log
  if !too_low_date_count.empty?
    puts "Not enough samples on date:"
    cpldc = CompactDatePrint.new(too_low_date_count)
    cpldc.log
  end
end

def simple_interpolate(val1, val0, t1, t0, tx, debug = false)
  t_prop = (tx - t0) / (t1 - t0)
  res = val0 + (val1 - val0) * t_prop
  puts "Interpolate: T1 #{val1} T0 #{val0} dt1 #{t1} dt0 #{t0} at dt #{tx}" if debug
  res
end

def interpolate_rawdata_onto_30minute_boundaries(station_name, rawdata, start_date, end_date, max_minutes_between_samples)
  puts "station_name = #{station_name}"
  puts "Interpolating data onto 30min boundaries for #{station_name} between #{start_date} and #{end_date} => #{rawdata.length} samples"
  temperatures = []
  solar_insolance = []

  start_time = start_date.to_datetime

  end_time = end_date.to_datetime
  
  date_times = rawdata.keys
  mins30step = (1.to_f/48)

  start_date.to_datetime.step(end_date.to_datetime, mins30step).each do |datetime|
    begin
      if date_times.last < datetime
        puts "Problem shortage of data for this weather station, terminating interpolation early at #{datetime}"
        return [temperatures, solar_insolance]
      end
      index = date_times.bsearch_index{|x, _| x >= datetime } # closest

      time_before = date_times[index-1]
      time_after = date_times[index]
      minutes_between_samples = (time_after - time_before) * 24 * 60

      if minutes_between_samples <= max_minutes_between_samples && datetime > date_times.first
        # process temperatures

        temp_before = rawdata[date_times[index-1]][0]
        temp_after = rawdata[date_times[index]][0]
        debug = !@debug_start_date.nil? && datetime >= @debug_start_date && datetime <= @debug_end_date

        temp_val = simple_interpolate(temp_after.to_f, temp_before.to_f, time_after, time_before, datetime, debug).round(2)
        temperatures.push(temp_val)

        if debug
          puts "Interpolation for #{station_name} #{datetime} T = #{temp_before} to #{temp_after} => #{temp_val}"
          puts "mins between samples #{minutes_between_samples} versus limit #{max_minutes_between_samples}"
        end
        # process solar insolence

        solar_before = rawdata[date_times[index - 1]][1]
        solar_after = rawdata[date_times[index]][1]
        solar_val = simple_interpolate(solar_after.to_f, solar_before.to_f, time_after, time_before, datetime).round(2)
        solar_insolance.push(solar_val)
      else
        temperatures.push(nil)
        solar_insolance.push(nil)
      end
    rescue Exception => e
      puts "Data Exception at #{datetime}"
      raise
    end
  end
  [temperatures, solar_insolance]
end

def process_area(area)
  puts '=' * 80
  puts area.inspect
  puts "Processing area #{area[:name]}"
  start_date = area[:start_date]
  end_date   = area[:end_date]
  max_minutes_between_samples = area[:max_minutes_between_samples]
  max_temp = area[:max_temperature]
  min_temp = area[:min_temperature]
  max_solar = area[:max_solar_insolence]
  solar_scale_factor = area[:solar_scale_factor]
  
  # load the raw data from webpages for each station (one day at a time)
  rawstationdata = {}
  area[:weather_stations_for_temperature].each do |station_name, weight|
    rawdata = get_raw_temperature_and_solar_data(station_name, start_date-1, end_date+1, max_temp, min_temp, max_solar)
    if !rawdata.empty?
      rawstationdata[station_name] = rawdata
    else
      puts "Warning: no data for station #{station_name}"
    end
  end

  # process the raw data onto 30 minute boundaries
  processeddata = {}
  rawstationdata.each do |station_name, rawdata|
    begin
      processeddata[station_name] = interpolate_rawdata_onto_30minute_boundaries(station_name, rawdata, start_date, end_date, max_minutes_between_samples)
    rescue Exception => e
      puts "Error interpolating data for #{station_name}, skipping station"
      puts e
    end
  end

  # take temperatures, solar from muliple weather stations and calculate a weighted average across a number of local weather stations
  temperatures = {}
  solar_insolence = {}
  if area[:method] == :weighted_average  # for every 30 minutes in period loop through all the station data averaging
    mins30step = (1.to_f/48)
  
    loop_count = 0
    start_date.to_datetime.step(end_date.to_datetime, mins30step).each do |datetime|
      avg_sum_temp = 0.0
      sample_weight_temp = 0.0

      avg_sum_solar = 0.0
      sample_weight_solar = 0.0

      daytime = daytime?(datetime, area[:latitude], area[:longitude], -1.25)
      
      processeddata.each do |station_name, data|
        # average temperatures
        if !data[0][loop_count].nil?
          temp_weight = area[:weather_stations_for_temperature][station_name]
          avg_sum_temp += data[0][loop_count] * temp_weight
          sample_weight_temp += temp_weight
        end
        
        # average solar insolence
        if !data[1][loop_count].nil? && area[:weather_stations_for_solar].key?(station_name)
          solar_weight = area[:weather_stations_for_solar][station_name]
          avg_sum_solar += data[1][loop_count] * solar_weight * solar_scale_factor if daytime
          sample_weight_solar += solar_weight
        end
      end
      
      avg_temp = sample_weight_temp > 0.0 ? (avg_sum_temp / sample_weight_temp).round(2) : nil
      avg_solar = sample_weight_solar > 0.0 ? (avg_sum_solar / sample_weight_solar).round(2) : nil
      temperatures[datetime] = avg_temp
      solar_insolence[datetime] = avg_solar
      loop_count += 1
    end
  else
    raise "Unknown weather station processing method for #{area[:name]} area[:method]"
  end
  [temperatures, solar_insolence]
end

def unique_list_of_dates_from_datetimes(datetimes)
  dates = {}
  datetimes.each do |datetime|
    dates[datetime.to_date] = true
  end
  dates.keys
end

def write_csv(filename, data, orientation, append)
  # implemented using file operations as roo & write_xlsx don't seem to support writing csv and spreadsheet/csv have BOM issues on Ruby 2.5
  puts "Writing csv file #{filename}: #{data.length} items in format #{orientation}"
  File.open(filename, append ? 'a' : 'w') do |file|  
    if orientation == :landscape
      dates = unique_list_of_dates_from_datetimes(data.keys)
      dates.each do |date|
        line_count = 0
        line = date.strftime('%Y-%m-%d') << ','
        (0..47).each do |half_hour_index|
          datetime = DateTime.new(date.year, date.month, date.day, (half_hour_index / 2).to_i, half_hour_index.even? ? 0 : 30, 0)
          if  data.key?(datetime)
            if data[datetime].nil?
              line << ','
            else
              line << data[datetime].to_s << ','
            end
            line_count += 1
          end
        end
        file.puts(line) if line_count == 48
      end
    else
      data.each do |datetime, value|
        line << datetime.strftime('%Y-%m-%d %H:%M:%S') << ',' << value.to_s << '\n'
        file.puts(line)
      end
    end  
  end
end

def parse_command_line
  args = ARGV.clone
  while !args.empty?
    if args[0] == '-dates' && args.length >= 3
      @start_date = Date.parse(args[1])
      @end_date = Date.parse(args[2])
      puts "Processing temperatures and solar between fixed dates #{@start_date} and #{@end_date}"
      set_start_end_dates_for_all_areas(@start_date, @end_date)
      @fixed_dates = true
      args.shift(3)  
    elsif args[0] == '-region' && args.length >= 2
      @one_region = args[1]
      puts "Processing temperatures and solar for one region #{@one_region}"
      args.shift(2)
    elsif args[0] == '-threads' && args.length >= 2
      @num_threads = args[1].to_i
      puts "Downloading data using #{@num_threads} threads"
      args.shift(2)
    elsif args[0] == '-usecache'
      puts "Using cache"
      @use_cache = true
      args.shift(1)
    elsif args[0] == '-debugdaterange'  && args.length >= 3
      @debug_start_date = Date.parse(args[1])
      @debug_end_date = Date.parse(args[2])
      puts "Debugging dates between #{@debug_start_date} and #{@debug_end_date}"
      args.shift(3)
    else
      puts "Arguments -dates date1 date2 || -region region || -threads num_threads || -usecache || -debugdaterange d1 d2"
      puts "provided arguments #{args}"
      puts 'Example: ruby script\downloadSolarAndTemperatureData.rb -region Frome -threads 1 -usecache -debugdaterange 23/8/2013 24/8/2013'
      args = []
    end
  end
end

def set_start_end_dates_for_all_areas(start_date, end_date)
  @areas.each do |area|
    area[:start_date] = start_date
    area[:end_date] = end_date
  end
end

def last_downloaded_date(temperature_filename, solar_filename)
  temp_data = Temperatures.new('temperatures')

  if !File.file?(temperature_filename)
    puts "Unable to find file #{temperature_filename}"    
    return nil 
  end
  TemperaturesLoader.new(temperature_filename, temp_data)
  puts "Loaded #{temp_data.length} days of temperatures from #{temperature_filename}"
  last_date = temp_data.keys.last
  puts "last date of previous download = #{last_date}"
  last_date
end

# MAIN

@fixed_dates = nil
@one_region = false

parse_command_line

@areas.each do |area|
  next if @one_region != false && area[:name] != @one_region

  temp_filename = "#{INPUT_DATA_DIR}/" + area[:temperature_csv_file_name]
  solar_filename = "#{INPUT_DATA_DIR}/" + area[:solar_csv_file_name]

  if @fixed_dates.nil? # if dates not specified append data onto existing download
    start_date = last_downloaded_date(temp_filename, solar_filename)
    unless start_date.nil?
      area[:start_date] =  start_date + 1
      area[:end_date] = Date.today#  was -1 until 1Mar2019
    end
  else
    area[:start_date] =  @start_date
    area[:end_date] = @end_date
  end

  temperatures, solar_insolence = process_area(area)

  write_csv(temp_filename, temperatures, area[:csv_format], !@fixed_dates)
  write_csv(solar_filename, solar_insolence, area[:csv_format], !@fixed_dates)
end
