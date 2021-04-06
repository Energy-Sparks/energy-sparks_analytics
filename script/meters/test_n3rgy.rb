require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

class DCCMeters
  def self.available_meters
    @@available_meters ||= meter_config.transform_keys { |mpxn| real_mpxn(mpxn) }
  end

  def self.all_mpxns
    available_meters.keys
  end

  def self.meter_config
=begin
  ======kwh readings=================
    10:15:22: 1234567891000 Readings: 672 Missing: 122 2012-04-27 to 2014-02-27
    10:15:33: 1234567891002 Readings: 671 Missing: 169 2012-04-27 to 2014-02-27
    10:15:41: 1234567891004 Readings: 354 Missing: 73 2012-04-27 to 2013-04-15
    10:15:49: 1234567891006 Readings: 514 Missing: 69 2012-04-27 to 2013-09-22
    10:16:00: 1234567891008 Readings: 656 Missing: 167 2012-05-12 to 2014-02-27
    10:16:11: 1234567891010 Readings: 653 Missing: 317 2012-05-12 to 2014-02-27
    10:16:17: 1234567891012 Readings: 0 Missing: 31536  to
    10:16:25: 1234567891014 Readings: 653 Missing: 220 2012-05-14 to 2014-02-27
    10:16:30: 1234567891016 Readings: 0 Missing: 37920  to
    10:16:38: 1234567891018 Readings: 0 Missing: 37920  to
    10:16:46: 1234567891020 Readings: 0 Missing: 37920  to
    10:16:55: 1234567891022 Readings: 0 Missing: 37920  to
    10:17:06: 1234567891024 Readings: 494 Missing: 117 2012-10-22 to 2014-02-27
    10:17:55: 1234567891026 Readings: 652 Missing: 122 2012-05-17 to 2014-02-27
    10:18:46: 1234567891028 Readings: 652 Missing: 124 2012-05-17 to 2014-02-27
    10:18:51: 1234567891030 Readings: 106 Missing: 72 2012-05-17 to 2012-08-30
    10:19:49: 1234567891032 Readings: 789 Missing: 55 2012-01-01 to 2014-02-27
    10:20:37: 1234567891034 Readings: 601 Missing: 122 2012-07-07 to 2014-02-27
    10:21:18: 1234567891036 Readings: 520 Missing: 120 2012-09-26 to 2014-02-27
    10:22:05: 1234567891038 Readings: 593 Missing: 212 2012-07-13 to 2014-02-27
    Start date must not be before move in date: [2018-12-24T23:30].
    Start date must not be before move in date: [2018-12-24T23:30].
    10:22:21: 2000XXXXXX057 Readings: 437 Missing: 84 2020-01-25 to 2021-04-05
    You do not have a registered consent to access property '2200013480585'
    10:22:27: 5083XXXXXXXX6 Readings: 430 Missing: 73 2020-02-01 to 2021-04-05
    10:22:29: 22000156XXXXX Readings: 41 Missing: 40 2021-02-24 to 2021-04-05
=end
    @@meter_config ||= {
      1234567891000 => {},
      1234567891002 => {},
      1234567891004 => {},
      1234567891006 => {},
      1234567891008 => {},
      1234567891010 => {},
      1234567891012 => {}, # no kWh readings
      1234567891014 => {},
      1234567891016 => {}, # no kWh readings, tiered
      1234567891018 => {}, # no kWh readings, tiered
      1234567891020 => {}, # no kWh readings, tiered
      1234567891022 => {}, # no kWh readings, tiered
      1234567891024 => {}, # starts Oct 2012
      1234567891026 => {},
      1234567891028 => {},
      1234567891030 => {}, # only 3 months data
      1234567891032 => {},
      1234567891034 => {},
      1234567891036 => {},
      1234567891038 => {},
      2234567891000 => {},
      2234567891001 => { fuel_type: :gas },
      1 => { production: true }, # PH
      2 => { production: true }, # DH
      3 => { production: true }, # JH-E
      4 => { production: true, fuel_type: :gas }, # KH-G
      5 => { production: true }, #JB
    }
  end

  def self.meter(mpxn)
    DCCMeter.new(mpxn, available_meters[mpxn])
  end

  private

  def self.real_mpxn(mpxn)
    mpxn_map.key?(mpxn) ? mpxn_map[mpxn] : mpxn
  end

  def self.mpxn_map
    # for priv*cy hold MPXN's in an environment variable
    pairs = ENV['N3RGY_LIVE_MPXN'].split(',')
    @mpxn_map ||= pairs.map { |pair| pair.split('=').map(&:to_i) }.to_h
  end

  class DCCMeter
    attr_reader :mpxn
    def initialize(mpxn, config)
      @mpxn = mpxn
      @config = config
    end

    def api_key
      production? ? ENV['N3RGY_API_KEY'] : ENV['N3RGY_SANDBOX_API_KEY']
    end

    def base_url
      production? ? 'https://api.data.n3rgy.com/' : 'https://sandboxapi.data.n3rgy.com/'
    end

    def base_consent_url
      production? ? 'https://consent.data.n3rgy.com/' : 'https://consentsandbox.data.n3rgy.com/'
    end

    def fuel_type
      @config.fetch(:fuel_type, :electricity)
    end

    private

    def production?
      @config.fetch(:production, false)
    end
  end
end

def log(in_str)
  str = DateTime.now.strftime('%H:%M:%S: ') + in_str
  puts str
  open('./DCC/n3rgy mpan log.text', 'a') { |f|
    f.puts str
  }
end

def save_csv(fuel_type, readings, mpxn, dtt = '')
  CSV.open(filename(mpxn, 'meter_readings-', dtt), 'w') do |csv|
    csv << ['date', 'days kWh', 'type', 'fuel_type', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings[fuel_type][:readings].each do |date, one_days_readings|
      csv << [date, one_days_readings.one_day_kwh, one_days_readings.type, fuel_type, one_days_readings.kwh_data_x48].flatten
    end
  end

  CSV.open(filename(mpxn, ' missing data ', dtt), 'w') do |csv|
    readings[fuel_type][:missing_readings].each do |dt|
      csv << [ dt ]
    end
  end
end

def tariffs(mpxn)
  meter = DCCMeters.meter(mpxn)
  tariff_data = load_yaml(meter.fuel_type, mpxn)
  td = N3rgyTariffs.new(tariff_data)
  parameterised_tariff = td.parameterise
  energy_sparks_tariffs = N3rgyToEnergySparksTariffs.new(parameterised_tariff)
  meter_attributes = energy_sparks_tariffs.convert
  save_yaml(meter.fuel_type, meter_attributes, mpxn, 'meter-attributes-')
end

def load_yaml(fuel_type, mpxn, dtt = '')
  name = filename(mpxn, 'tariffs-', dtt, '.yaml')
  return nil unless File.exist?(name)
  puts "Loading file from #{name}"
  YAML.load_file(name)
end

def save_yaml(fuel_type, tariff_data, mpxn, dtt = '') 
  name = filename(mpxn, 'tariffs-', dtt, '.yaml')
  puts "Saving file #{name}"
  File.open(name, 'w') { |f| f.write(YAML.dump(tariff_data)) }
end

def filename(mpxn, type, dtt = '', ext = '.csv')
  './DCC/dcc-' + type + dtt + mpxn.to_s + ext
end

def check_one_mpxn(mpxn, cmd)
  end_date    = Date.today
  start_date  = end_date - 13 * (364 / 12)

  download_meter_readings(mpxn, start_date, end_date, DateTime.now.strftime('%H %M %S'))
end

def download_meter_readings(mpxn, start_date, end_date, dtt = '')
  meter = DCCMeters.meter(mpxn)

  n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)

  readings = n3rgy_data.readings(mpxn, meter.fuel_type, start_date, end_date)

  log(sprintf('%-14.14s', mpxn) + analyse_readings(meter.fuel_type, readings))
  save_csv(meter.fuel_type, readings, mpxn, dtt)
end

def download_tariffs(mpxn, start_date, end_date, dtt = '')
  meter = DCCMeters.meter(mpxn)

  n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)

  tariffs = n3rgy_data.tariffs(mpxn, meter.fuel_type, start_date, end_date)

  save_yaml(meter.fuel_type, tariffs, mpxn, dtt)
end

def export(mpxn)
  download_meter_readings(mpxn, start_date(mpxn), end_date(mpxn))
  download_tariffs(mpxn, start_date(mpxn), end_date(mpxn))
end

def start_date(mpxn)
  meter = DCCMeters.meter(mpxn)
  n3rgy = n3rgy_data(mpxn)
  dt = n3rgy.cache_start_datetime(mpxn: mpxn, fuel_type: meter.fuel_type)
  dt.to_date
end

def end_date(mpxn)
  meter = DCCMeters.meter(mpxn)
  n3rgy = n3rgy_data(mpxn)
  dt = n3rgy.cache_end_datetime(mpxn: mpxn, fuel_type: meter.fuel_type)
  dt.to_date
end

def n3rgy_data(mpxn)
  meter = DCCMeters.meter(mpxn)
  MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)
end

def monitor(mpxns, cmd)
  sleep_times = [[10, 60], [60, 60], [600, 24 * 6]]

  sleep_times.each do |(sleep_period, count)|
    count.times do
      mpxns.each do |mpxn|
        check_one_mpxn(mpxn, cmd)
      end
      sleep sleep_period
    end
  end
end

def analyse_readings(fuel_type, readings)
  start_date = readings[fuel_type][:readings].keys.min
  end_date =  readings[fuel_type][:readings].keys.max
  "Readings: #{readings[fuel_type][:readings].length} Missing: #{readings[fuel_type][:missing_readings].length} #{start_date} to #{end_date}"
end

# currently the new library doesn't work
def grant_old_consent(mpxn)
  logging = { puts: true, ap: { limit: 5 } }
  example_consent_file_link = 'sandbox testing PH 6Mar2021'
  puts "Using API key #{ENV['N3RGY_SANDBOX_API_KEY']}"
  n3rgy = MeterReadingsFeeds::N3rgy.new(api_key: ENV['N3RGY_SANDBOX_API_KEY'], debugging: logging, production: true)
  ap n3rgy.grant_trusted_consent(mpxn, example_consent_file_link)
end

# parked here temporarily as doesn't work
def grant_new_consent(mpxn, meter)
  n3rgy_consent = MeterReadingsFeeds::N3rgyConsent.new(api_key: meter.api_key, base_url: meter.base_consent_url)
  n3rgy_consent.grant_trusted_consent(mpxn, 'testing sandbox')
end

def command_line_options
  [
    { arg: '-mpxn',     args: 1, var: :mpxns, parse: 'mpxn_split_list', help: 'comma separated list' },
    { arg: '-all',      args: 0, var: :all_meters },
    { arg: '-data',     args: 0, var: :download_data },
    { arg: '-monitor',  args: 0, var: :monitor },
    { arg: '-consent',  args: 0, var: :consent },
    { arg: '-dates',    args: 0, var: :dates },
    { arg: '-export',   args: 0, var: :export },
    { arg: '-tariffs',  args: 0, var: :tariffs },
    { arg: '-available_meters',   args: 0, var: :available_meters }
  ]
end

def mpxn_split_list(list)
  list.split(',').map(&:to_i)
end

puts

cmd = ParseCommandLine.new(command_line_options)
cmd.parse

mpxns = cmd.all_meters ? DCCMeters.all_mpxns : cmd.mpxns
mpxns.each do |mpxn|
  begin
    meter = DCCMeters.meter(mpxn)
    n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)
    if n3rgy_data.status(mpxn) == :consent_required && cmd.consent
      grant_new_consent(mpxn, meter)
    end

    puts "#{mpxn} #{start_date(mpxn)} #{end_date(mpxn)}" if cmd.dates

    tariffs(mpxn) if cmd.tariffs
    export(mpxn) if cmd.export
  rescue => e
    puts e.message
    puts e.backtrace
  end
end

exit

ap DCCMeters.available_meters if cmd.available_meters

monitor(cmd.mpxns, cmd) if cmd.monitor
