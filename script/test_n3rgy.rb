require 'benchmark'
require 'csv'
require 'require_all'
require 'date'
require_relative '../lib/dashboard.rb'

# Test script to understand detailed workings of n3rgy JSON API
# - you need to set N3RGY_APP_KEY environment variable


def save_readings_to_csv(mpxn, fuel_type, readings)
  filename = 'Results\\' + "N3rgy #{mpxn.to_s} #{fuel_type}.csv"
  puts "Saving readings to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings.each do |date, kwh_x48|
      csv << [date, kwh_x48.sum, kwh_x48].flatten
    end
  end
end

def calculate_total_costs(data)
  total_£ = total_standing_charges_£ = 0.0
  data[:kwh][:readings].keys.each do |date|
    (0..47).each do |hh_i|
      total_£ += data[:kwh][:readings][date][hh_i] * data[:cost][:kwh_tariffs][date][hh_i]
    end

    sc = data[:cost][:standing_charges].select { |dr, _v| date >= dr.first && date <= dr.last }
    total_standing_charges_£ += sc.values[0]
  end
  [total_£, total_standing_charges_£]
end

def process_one_mpxn(n3rgy, mpxn)
  all_data = nil
  puts ('=' * 40) +  mpxn.to_s + ('=' * 40)

  bm = Benchmark.realtime {
    puts "Status:  #{n3rgy.mpxn_status(mpxn)}"

    all_data = n3rgy.all_data(mpxn)

    all_data.each do |fuel_type, data|
      puts "===============#{fuel_type}=================="
      puts "Fuel        #{fuel_type}"
      if data.nil?
        puts "No data"
      else
        puts "Units:      #{n3rgy.units(mpxn, fuel_type)}"
        puts "Start:      #{n3rgy.start_date(mpxn, fuel_type)}"
        puts "End:        #{n3rgy.end_date(mpxn, fuel_type)}"
        puts "Days:       #{data[:kwh][:readings].length}"
        
        total_kwh = data[:kwh][:readings].values.map { |kwh_x48| kwh_x48.sum }.sum
        total_kwh ||= 0.0
        puts "Total kwh:  #{total_kwh.round(0)}"

        total_£, total_standing_charges_£ = calculate_total_costs(data)
        puts "£: kwh:     £#{total_£.round(0)}"
        puts "£: sc:      £#{total_standing_charges_£.round(0)}"
        puts "Missing:    #{data[:kwh][:missing_readings].length}"
      end
    end
  }
  puts "Time:       #{bm.round(1)}s"
  all_data
end

def test_consent_process(n3rgy, mpxn)
  puts ('=' * 30) + ' testing consents for ' +  mpxn.to_s + ('=' * 30)
  example_consent_file_link = 'https://es-active-storage-production.s3.eu-west-2.amazonaws.com/1isvxhf6fk4ep7nqo7yi4v71umky?response-content-disposition=inline%3B%20filename%3D%22Energy%20Sparks%20Case%20Study%201%20-%20Freshford%20Freezer.pdf%22%3B%20filename%2A%3DUTF-8%27%27Energy%2520Sparks%2520Case%2520Study%25201%2520-%2520Freshford%2520Freezer.pdf&response-content-type=application%2Fpdf&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJ53OZKG2W5BDLHXA%2F20210123%2Feu-west-2%2Fs3%2Faws4_request&X-Amz-Date=20210123T182223Z&X-Amz-Expires=300&X-Amz-SignedHeaders=host&X-Amz-Signature=797b1523784280e5beb2e746f75be95a3c256c06e5e4111d3825a613a107e91a'

  session_id = n3rgy.session_id(mpxn)
  puts "Session id #{session_id}"
  puts ('=' * 30) + ' grant trusted consent ' + ('=' * 30)
  ap n3rgy.grant_trusted_consent(mpxn, example_consent_file_link)
  puts ('=' * 30) + ' withdraw trusted consent ' + ('=' * 27)
  ap n3rgy.withdraw_trusted_consent(mpxn)
end

def test_appendix_a_sandbox_mpxns_permissions(n3rgy)
  puts ('=' * 30) +  ' testing sandbox mpxn statuses ' + ('=' * 03)
  appendix_a_sandbox_mpxns = [
    1234567891000, 1234567891002, 1234567891004, 1234567891006,
    1234567891008, 1234567891010, 1234567891012, 1234567891014,
    1234567891016, 1234567891018, 1234567891020, 1234567891022,
    1234567891024, 1234567891026, 1234567891028, 1234567891030,
    1234567891032, 1234567891034, 1234567891036, 1234567891038,
    2234567891000,
  ]

  appendix_a_sandbox_mpxns.each do |mpxn|
    puts "#{mpxn}: #{n3rgy.mpxn_status(mpxn)}"
  end
end

def download_all_permissioned_data(n3rgy)
  puts '=' * 90
  puts ('=' * 30) +  ' downloading all data for permissoned mpxns ' + ('=' * 16)
  puts '=' * 90

  mpxns = n3rgy.mpxns
  ap mpxns.sort

  mpxns.sort.each do |mpxn|
    data = process_one_mpxn(n3rgy, mpxn)
    data.each do |fuel_type, data_per_fuel|
      save_readings_to_csv(mpxn, fuel_type, data_per_fuel[:kwh][:readings])
    end
  end
end

logging = { puts: true, ap: { limit: 5 } }
logging = nil

n3rgy = MeterReadingsFeeds::N3rgy.new(debugging: logging)
# process_one_mpxn(n3rgy, 2234567891000)

puts "testing inventory process - only works in production environment?"
n3rgy.inventory

test_consent_process(n3rgy, 2234567891000)

test_appendix_a_sandbox_mpxns_permissions(n3rgy)

download_all_permissioned_data(n3rgy)

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
