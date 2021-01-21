require 'digest'
require 'net/http'
require 'json'
require 'uri'
require 'tzinfo'
require 'amazing_print'
require 'faraday'
require 'faraday_middleware'
require 'benchmark'
require 'csv'
# Test script to understand detailed workings of n3rgy JSON API
# - shortcoming: doesn't propogate standing charges for each day, only adds in for 1st day of that charge (change)
# - you need to set N3RGY_APP_KEY environment variable

class N3rgy
  def initialize(app_key = ENV['N3RGY_APP_KEY'])
    @app_key = app_key
  end

  def mpans
    get_json_data['entries'].map(&:to_i)
  end

  def kwh_and_tariff_data_for_mpan(mpan)
    puts '=' * 40 + mpan.to_s + '=' * 40
    data = { kwh: {}, cost: 0.0 }
    type =  get_json_data(mpan: mpan)
    type['entries'].each do |fuel_type|
      data_types =  get_json_data(mpan: mpan, fuel_type: fuel_type)['entries']
      data_types.each do |data_type| # typically either 'consumption' i.e. kWh or 'tariff' i.e. £
        phases = get_json_data(mpan: mpan, fuel_type: fuel_type, data_type: data_type)['entries']
        puts "Phases: #{phases.join(',')}"
        phases.each do |phase|
          meter_data_type_range = meter_date_range(mpan, fuel_type, data_type, phase)
          puts "Got data between #{meter_data_type_range.first} and #{meter_data_type_range.last} for #{mpan} #{fuel_type} #{data_type} #{phase}"
          d = half_hourly_data(mpan, meter_data_type_range.first, meter_data_type_range.last, fuel_type, data_type, phase)
          data = deep_merge_data(data, d)
        end
      end
    end
    data
  end

  private

  def deep_merge_data(base, additional)
    {
      kwh:  base[:kwh].merge(additional[:kwh]),
      cost: base[:cost] + additional[:cost]
    }
  end

  def half_hourly_data(mpan, start_date, end_date, fuel_type, data_type, phase = 1)
    kwhs = {}
    total_cost = 0.0
    (start_date..end_date).each_slice(90) do |date_range_max_90days|
      raw_data = get_json_data(mpan: mpan, fuel_type: fuel_type, data_type: data_type, phase: phase,
                                start_date: date_range_max_90days.first, end_date: date_range_max_90days.last)

      case data_type
      when 'consumption'
        kwhs.merge!(process_consumption_data(raw_data))
      when 'tariff'
        costs = process_cost_data(raw_data)
        # TODO: should add in standard charge for each day of date range, not just once?
        cost = costs[:standing_charges] + costs[:prices][:costs].values.map(&:sum).sum
        total_cost += cost
      else
        raise StandardError, "Unknown data type #{data_type}"
      end
      puts raw_data['message'] if raw_data.key?('message')
    end
    puts "total kwhs #{kwhs.values.map(&:sum).sum} costs #{total_cost}"
    {
      kwh:  kwhs,
      cost: total_cost
    }
  end

  def process_consumption_data(raw_data)
    readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour kwh]
    raw_data['values'].each do |reading|
      date, half_hour_index = timestamp_to_date_and_half_hour_index(reading)
      kwh = reading['value']
      readings[date][half_hour_index] += kwh
    end
    puts "Processes #{readings.length} dates"
    puts "sub total kwh = #{readings.values.map(&:sum).sum}"
    readings
  end

  def timestamp_to_date_and_half_hour_index(reading)
    dt = DateTime.parse(reading['timestamp'])
    date = dt.to_date
    half_hour_index = ((dt - date) * 48).to_i
    [date, half_hour_index]
  end

  # there is no interface to provide the first and last meter readings
  # this is probably because the first time the data is accessed it needs
  # to make a GSM request of a remote meter, and until it makes this request it doesn't
  # know the data range stored in the meter?
  def meter_date_range(mpan, fuel_type, data_type, phase)
    raw_data = get_json_data(mpan: mpan, fuel_type: fuel_type, data_type: data_type, phase: phase,
                              start_date: Date.today, end_date: Date.today + 1)
    start_date = Date.strptime(raw_data['availableCacheRange']['start'], '%Y%m%d') + 1
    end_date = Date.strptime(raw_data['availableCacheRange']['end'], '%Y%m%d') - 1
    start_date..end_date
  end

  def process_cost_data(raw_data)
    costs = {}
    raw_data.each_key do |key|
      case key
      when 'values'
        costs = process_cost_values(raw_data['values'])
      when 'resource', 'responseTimestamp', 'start', 'end', 'availableCacheRange'
        # known returned data, currently ignored
      else
        raise StandardError, "Unknown cost attribute #{key}"
      end
    end

    puts "keys = #{raw_data.keys}"
    costs
  end

  def process_cost_values(cost_values_array)
    standing_charges = 0.0
    prices = {}
    raise StandardError, "Error: more than one cost value set, unexpected, num =  #{cost_values_array.lengthy}" if cost_values_array.length > 1
    cost_values_array[0].each do |key, cost_values|
      case key
      when 'standingCharges'
        cost_values.each do |standing_charge|
          standing_charges += standing_charge['value']
          raise StandardError, "Unknown standard charge type in #{standing_charge.keys}" unless standing_charge.keys.all?{ |key| ['startDate', 'value'].include?(key) }
          puts "Standing charges: #{standing_charges} - TODO: which probably needs to be applied daily until the next change in standing charge"
        end
      when 'prices'
        puts "Got #{cost_values.length} prices"
        prices = process_prices(cost_values)
        puts "sub total £ = #{prices[:costs].values.map(&:sum).sum}"
      else
        raise StandardError, "Unknown cost type #{key}"
      end
    end
    { prices: prices, standing_charges: standing_charges }
  end

  # it appears that there is either a single price for a half hour period
  # or two - one above and one below a threshold (volume discount?)
  def process_prices(price_values)
    costs = Hash.new { |h, k| h[k] = Array.new(48, 0.0) } # [date] => [48x half hour costs]
    thresholds = 0
    unknowns = Hash.new(0)
    price_values.each do |reading|
      date, half_hour_index = timestamp_to_date_and_half_hour_index(reading)
      
      if reading.key?('value')
        cost = reading['value']
        costs[date][half_hour_index] += cost
      end
      if reading.key?('prices') && reading['prices'].is_a?(Array)
        cost = reading['prices'].sum{ |threshold_price| threshold_price['value'] }
        costs[date][half_hour_index] += cost
      end
      if reading.key?('thresholds')
        thresholds  += 1
      end
      reading.each_key do |key|
        if !['prices', 'value', 'thresholds', 'timestamp'].include?(key)
          unknowns[key] += 1
        end
      end
    end
    { costs: costs, thresholds: thresholds, unknowns: unknowns }
  end

  def get_json_data(mpan: nil, fuel_type: nil, data_type: nil, phase: nil, start_date: nil, end_date: nil)
    url = json_url(mpan, fuel_type, data_type, phase, start_date, end_date)
    puts "JSON: #{url}"
    connection = Faraday.new(url, headers: authorization)
    response = connection.get
    raw_data = JSON.parse(response.body)
  end

  def authorization
    { 'Authorization' => @app_key }
  end

  def half_hourly_query(start_date, end_date)
    '?start=' + url_date(start_date) + '&end=' + url_date(end_date, true) + '&granularity=halfhour'
  end

  def json_url(mpan, fuel_type, data_type, phase, start_date, end_date)
    url = 'https://sandboxapi.data.n3rgy.com/'
    url += mpan.to_s + '/' unless mpan.nil?
    url += fuel_type + '/' unless fuel_type.nil?
    url += data_type + '/' unless data_type.nil? 
    url += phase.to_s unless phase.nil?
    url += half_hourly_query(start_date, end_date) unless start_date.nil? || end_date.nil?
    url
  end

  def url_date(date, end_date = false)
    end_date ? date.strftime('%Y%m%d2359') : date.strftime('%Y%m%d0000')
  end
end

def save_readings_to_csv(mpan, readings)
  filename = 'Results\N3rgy ' + mpan.to_s + '.csv'
  puts "Saving readings to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings.each do |date, kwh_x48|
      csv << [date, kwh_x48.sum, kwh_x48].flatten
    end
  end
end

mpans = N3rgy.new.mpans
ap mpans
mpans.each do |mpan|
  data = N3rgy.new.kwh_and_tariff_data_for_mpan(mpan)
  save_readings_to_csv(mpan, data[:kwh])
end
exit
data.each_with_index do |item, count|
  puts '-' * 10 + count.to_s + '-' * 10
  N3rgy.process_meter_readings(item)
end
exit
data = []
bm = Benchmark.realtime {
  data =  N3rgy.new.half_hourly_data(1234567891034, Date.new(2012, 7, 7), Date.new(2014, 3, 1))
}
puts data.length
puts bm.round(3)


#interface spec

class N3rgyRawData
  def initialize(app_key = ENV['N3RGY_APP_KEY']); end
  def permissioned_mpans; end
  def metadata(mpan); end # TBD, but probably a hash
  def mpan_status; end # returns as enumeration e.g. permissioned, adopted, not available etc. TBD
  def postcode; end # to be used as part of audit, permissioning process
  def start_date; end
  def end_date; end
  def historic_meter_data(mpan, start_date, end_date); end # { channel?, kwhs: { date => [kwhx48]}, prices: { date => [£x48]} error_log => {} }
  def standing_charges(mpan, start_date, end_date) # hash TBD
  def permission_mpan(mpan, url_to_uploaded_utility_bill_scan) # this may be implemented outside this API
end
