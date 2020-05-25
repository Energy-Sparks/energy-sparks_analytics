require 'awesome_print'
require 'digest'
require 'net/http'
require 'json'
require 'uri'
require 'tzinfo'
require 'open-uri'
require 'csv'
# Test programme to understand Hildebrand Glo API
#
# you need to set environment variables HILDEBRAND_USER_ID and HILDEBRAND_APP_KEY for this to work
#
# Working command:
#
# curl -X GET
#      -H "userId: HILDEBRAND_USER_ID"
#      -H "Authorization: Basic HILDEBRAND_APP_KEY"
#         "https://api.glowmarkt.com/api/v0-1/resource/f4c88949-73b3-49ae-8112-60e3e7ce65de/readings?from=2019-06-01T00:00:00&to=2019-06-10T23:59:59&period=PT30M&oﬀset=-60&function=sum"
# or
# curl  --location
#       --request GET 'https://api.glowmarkt.com/api/v0-1/resource/c0013a52-6a15-492c-bcab-38aeaa483386/readings?from=2020-01-01T00:00:00&to=2020-03-31T23:59:59&period=P1M&offset=-60&function=sum'
#       --header 'userId: HILDEBRAND_USER_ID'
#       --header 'Authorization: Basic HILDEBRAND_APP_KEY'

EXAMPLE_METER_RESOURCE = 'c0013a52-6a15-492c-bcab-38aeaa483386'

require 'faraday'

class HildebrandGlo
  GET_READINGS_URL = 'https://api.glowmarkt.com/api/v0-1/resource/'
  GET_RESOURCES_URL = 'https://api.glowmarkt.com/api/v0-1/resource/'
  GET_USERS_URL = 'https://api.glowmarkt.com/api/v0-1/account'

  def initialize
  end

  def meter_readings(start_date, end_date, resource_id)
    readings = {}
    (start_date..end_date).each_slice(10) do |date_range_max_10days|
      readings.merge!(meter_readings_10_day_chunk(date_range_max_10days.first, date_range_max_10days.last, resource_id))
    end
    puts "Total kwh = #{readings.values.map(&:sum).sum}"
    readings
  end

  def all_users
    json(GET_USERS_URL)
  end

  def user_id(user_name)
    all_users.detect{ |user_definition| user_definition['name'] == user_name }['userId']
  end

  def available_resources(user_id = ENV['HILDEBRAND_USER_ID'])
    json(GET_RESOURCES_URL, user_id)
  end

  def resource_readings(resource)
    puts '*' * 40 + 'reading resources for ' + resource['name'] + '*' * 40
    ap resource
  end

  def save_readings_to_csv(name, resourceId, start_date, end_date)
    puts '^' * 40 + name + '^' * 40
    readings = HildebrandGlo.new.meter_readings(Date.new(2019, 3, 20), Date.new(2019, 6, 1), resourceId)

    filename = 'Results\Hildebrand ' + name + '.csv'
    puts "Saving readings to #{filename}"
    CSV.open(filename, 'w') do |csv|
      csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
      readings.each do |date, kwh_x48|
        csv << [date, kwh_x48.sum, kwh_x48].flatten
      end
    end
  end

  # there is no mechanism in advance to determine the 1st and last meter dates
  # and given you can only query half hourly 10 days at a time you don't
  # want to query 10 years data at 10 day intervals to find the relevent data
  # you could query backwards until you find no data, but this would fail if
  # there was a gap in the data of more than ~10 days
  # therefore query the data a year at a time, then a month at a time, then a day at a time
  # to drill down to days when you have valid data
  # apply a criteria of a minimum of 1 kWh or consumption in a given day for the data to be valid
  # there seems to be some very small spurious non nil kWh values coming back from historic dates e.g. 2015 for 3 phase
  # clamp meters, which needs filtering out
  # - TODO(PH, 25May2020) - needs refactor
  def find_valid_dates(meter_resource_id = EXAMPLE_METER_RESOURCE)
    max_year = Date.today.year
    years = (2010..max_year).to_a.map{ |year| Date.new(year, 1, 1)..Date.new(year, 12, 31) }
    months = {} # [month] = sum kwh
    years.each do |year_date_range|
      url = GET_READINGS_URL + meter_resource_id + json_meter_reading_query(year_date_range.first, year_date_range.last, 'P1M')
      years_data = json(url, ENV['HILDEBRAND_USER_ID'])['data']
      next if years_data.nil?
      months.merge!( years_data.map{ |months_data| [ hildebrand_time_parse(months_data[0]), months_data[1] ] }.to_h)
    end
    months_with_good_data = months.select{ |_date, kwh| !kwh.nil? && kwh > 1.0 }
    days = {}
    months_with_good_data.each do |month_date, kwh|
      last_date_of_month = Date.new(month_date.year + (month_date.month == 12 ? 1 : 0), month_date.month == 12 ? 1 : month_date.month + 1, 1) - 1
      url = GET_READINGS_URL + meter_resource_id + json_meter_reading_query(month_date, last_date_of_month, 'P1D')
      months_data = json(url, ENV['HILDEBRAND_USER_ID'])['data']
      days.merge!( months_data.map{ |days_data| [ hildebrand_time_parse(days_data[0]), days_data[1] ] }.to_h)
    end
    days_with_good_data = days.select{ |_date, kwh| !kwh.nil? && kwh > 1.0 }
    {
      date_range: days_with_good_data.keys.first..days_with_good_data.keys.last,
      kwh: days_with_good_data.values.sum
    }
  end

  private

  def meter_readings_10_day_chunk(start_date, end_date, resource_id)
    readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour kwh]
    kwhs = {}

    raw_data = json_readings_query(start_date, end_date, resource_id)
    raw_data['data'].each do |reading|
      date, half_hour_index = parse_hildebrand_datetime_to_date_and_half_hour_index(hildebrand_time_parse(reading[0]))
      readings[date][half_hour_index] += reading[1].to_f # TODO(PH, 24May2020) really need to check to nil before .to_f
    end 

    readings
  end

  def parse_hildebrand_datetime_to_date_and_half_hour_index(dt)
    date = dt.to_date
    half_hour_index = dt.hour * 2 + (dt.min == 30 ? 1 : 0)
    [date, half_hour_index]
  end

  def json_readings_query(start_date, end_date, resource_id)
    url = GET_READINGS_URL + resource_id + json_meter_reading_query(start_date, end_date)
    # puts url
    json(url, ENV['HILDEBRAND_USER_ID'])
  end

  def json(url, user_id = nil)
    # puts url
    uri = URI.parse(URI.escape(url))
    headers = {'Authorization' => 'Basic ' + ENV['HILDEBRAND_APP_KEY']}
    headers.merge!({'userId' => user_id}) unless user_id.nil?
    # ap headers
    connection = Faraday.new(uri, headers: headers)
    response = connection.get
    JSON.parse(response.body)
  end

  def json_meter_reading_query(start_date, end_date, period = 'PT30M')
    '/readings?from=' + url_date(start_date) + '&to=' + url_date(end_date, true) + '&period=' + period + '&oﬀset=-60&function=sum'
  end

  def url_date(date, end_date = false)
    end_date ? date.strftime('%Y-%m-%dT23:59:59') : date.strftime('%Y-%m-%dT00:00:00') 
  end

  def hildebrand_time_parse(seconds_since_1_jan_1970)
    Time.new(1970, 1, 1, 0, 0, 0) + seconds_since_1_jan_1970
  end


end


# ap HildebrandGlo.new.find_valid_dates(EXAMPLE_METER_RESOURCE)

puts '=' * 40 + 'users' + '=' * 40
users = HildebrandGlo.new.all_users
ap users
user_names = users.map { |user_definition| user_definition['name'] }
ap user_names
user_names.each do |name|
  puts '-' * 40 + name + '-' * 40
  user_id = HildebrandGlo.new.user_id(name) # currently ignored as accessed via ENV variable directly
  resources = HildebrandGlo.new.available_resources(user_id)
  resources.each do |resource|
    puts '=' * 40 + resource['name'] + '=' * 40
    ap resource
    info =  HildebrandGlo.new.find_valid_dates(resource['resourceId'])
    unless info[:date_range].first.nil?
      puts "resourceId = #{resource['resourceId']}"
      puts "from #{info[:date_range].first.strftime('%Y-%m-%d')} to #{info[:date_range].last.strftime('%Y-%m-%d')}: #{info[:kwh]} kWh"
      HildebrandGlo.new.save_readings_to_csv(
        resource['name'], resource['resourceId'], info[:date_range].first, info[:date_range].last)
    else
      puts 'no dated data'
    end
    # HildebrandGlo.new.resource_readings(resource)
  end
end

# user_id = HildebrandGlo.new.user_id('Philip Haile')

