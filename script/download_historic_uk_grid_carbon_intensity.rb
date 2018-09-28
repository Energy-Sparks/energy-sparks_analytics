# BATCH Process tpo donwload historic UK grid carbon intensity(c) Energy Sparks 2018-
#
# API: https://api.carbonintensity.org.uk/
#
# example url: https://api.carbonintensity.org.uk/intensity/2017-09-18T12:00Z/2017-10-01T12:00Z
#
# NB: splits download into 30 day chunks - the max allowed by the API (31)
# NB: API has bug where it doesn't work over year end, so code currently splits into 2 requests, bug reported(PH 28Sep2018)
require 'net/http'
require 'json'
require 'date'
require 'logger'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

CSV_FILE = File.join(File.dirname(__FILE__), '../InputData/uk_carbon_intensity.csv')

@start_date = Date.new(2017, 9, 19) # 2017/9/19 is the first date data available, overwritten if csv exists
@end_date = Date.new(2018, 9, 26) # overwritten by today - 1

def make_url(start_date, end_date)
  end_date += 1
  url = 'https://api.carbonintensity.org.uk/intensity/'
  url += start_date.strftime('%Y-%m-%d') + 'T00:30Z/'
  url += end_date.strftime('%Y-%m-%d') + 'T00:00Z/'
  @logger.info "URL = #{url}"
  url
end

def download_data_from_web(start_date, end_date)
  url = make_url(start_date, end_date)
  response = Net::HTTP.get(URI(url))
  data = JSON.parse(response)
  data['data']
end

# converts JSON into data[datetime] = carbon intensity
def extract_readings(readings)
  data = {}
  readings.each do |reading|
    datetime = DateTime.parse(reading['from'])
    carbon = reading['intensity']['actual']
    data[datetime] = carbon
    # @logger.info "#{datetime} #{carbon}"
  end
  data
end

# downloads data between date range, splitting into API max 30 day chunks and avoiding year end bug
def download_data(start_date, end_date)
  data = {}
  (start_date..end_date).each_slice(30) do |days_30_range| # 31 day max url request, so chunk
    range_start = days_30_range.first
    range_end = days_30_range.last
    if range_start.year != range_end.year # bug in API, doesn;t work over year boundaries
      # split query - up until year end
      web_data = download_data_from_web(range_start, Date.new(range_start.year, 12, 31))
      data = data.merge(extract_readings(web_data))
      # and after year end
      web_data = download_data_from_web(Date.new(range_end.year, 1, 1), range_end)
      data = data.merge(extract_readings(web_data))
    else
      web_data = download_data_from_web(range_start, range_end)
      data = data.merge(extract_readings(web_data))
    end
  end
  @logger.info "Got #{data.length} values"
  data
end

# explicitly loop through expected readings, so can spot gaps in returned data;
# midnight on year end always seems to be missing......
def check_for_missing_data(readings, start_date, end_date)
  mins30step = (1.to_f/48)

  start_date.to_datetime.step(end_date.to_datetime, mins30step).each do |datetime|
    if !readings.key?(datetime)
      substitute_datetime = readings.keys.bsearch{|x, _| x >= datetime }
      readings[datetime] = readings[substitute_datetime]
      @logger.info "Missing reading at #{datetime} substituting #{readings[substitute_datetime]}"
    end
  end
  readings
end

# convert data[datetime] = carbon into data[date] = [48x 1/2 hour carbon readings]
def convert_to_date_arrays(readings)
  data = {}
  readings.each_slice(48) do |one_day|
    date = one_day.first[0].to_date
    data[date] = []
    one_day.each do |carbon|
      data[date].push(carbon[1])
    end
  end
  data
end

# find the final date of data written to csv file, or nil if file doesn;t exist
def csv_last_reading(filename)
  last_date = nil
  if File.exists?(filename)
    File.open(filename, 'r') do |file|
      last_date = Date.parse(file.readlines.last.split(',')[0])
    end
  end
  last_date
end

# save data to file in date, carbon val 0, ..... carbon val 48 - format
def write_csv(filename, data, append)
  puts "Writing csv file #{filename}: #{data.length} items from #{data.keys.first} to #{data.keys.last}"
  File.open(filename, append ? 'a' : 'w') do |file|  
    data.each do |date, one_days_values|
      dts = date.strftime('%Y-%m-%d')
      file.puts("#{dts}," + one_days_values.join(','))
    end
  end
end

# MAIN

last_reading_date_from_csv = csv_last_reading(CSV_FILE)

last_date = last_reading_date_from_csv

@start_date = last_date + 1 unless last_date.nil?

@end_date = Date.today - 1

readings = download_data(@start_date, @end_date)

readings = check_for_missing_data(readings, @start_date, @end_date)

day_readings = convert_to_date_arrays(readings)

write_csv(CSV_FILE, day_readings, !last_date.nil?)
