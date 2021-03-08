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
    @@meter_config ||= {
      1234567891000 => {},
      1234567891002 => {},
      1234567891004 => {},
      1234567891006 => {},
      1234567891008 => {},
      1234567891010 => {},
      1234567891012 => {},
      1234567891014 => {},
      1234567891016 => {},
      1234567891018 => {},
      1234567891020 => {},
      1234567891022 => {},
      1234567891024 => {},
      1234567891026 => {},
      1234567891028 => {},
      1234567891030 => {},
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
  open('./Results/n3rgy mpan log.text', 'a') { |f|
    f.puts str
  }
end

def save_csv(fuel_type, readings, mpxn)
  CSV.open(filename(mpxn, ' data '), 'w') do |csv|
    csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings[fuel_type][:readings].each do |date, one_days_readings|
      csv << [date, one_days_readings.one_day_kwh, one_days_readings.kwh_data_x48].flatten
    end
  end

  CSV.open(filename(mpxn, ' missing data '), 'w') do |csv|
    readings[fuel_type][:missing_readings].each do |dt|
      csv << [ dt ]
    end
  end
end

def filename(mpxn, type)
  './Results/n3rgy' +  type + mpxn.to_s + ' ' + DateTime.now.strftime('%H %M %S') + '.csv'
end

def check_one_mpxn(mpxn, cmd)
  meter = DCCMeters.meter(mpxn)

  end_date    = Date.today
  start_date  = end_date - 13 * (364 / 12)

  n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)

  readings = n3rgy_data.readings(mpxn, meter.fuel_type, start_date, end_date)

  log(sprintf('%-14.14s', mpxn) + analyse_readings(meter.fuel_type, readings))
  save_csv(meter.fuel_type, readings, mpxn)
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
  "Readings: #{readings[fuel_type][:readings].length} Missing: #{readings[fuel_type][:missing_readings].length}"
end

# currently the new library doesn't work
def grant_old_consent(mpxn)
  logging = { puts: true, ap: { limit: 5 } }
  example_consent_file_link = 'sandbox testing PH 6Mar2021'
  n3rgy = MeterReadingsFeeds::N3rgy.new(api_key: ENV['N3RGY_SANDBOX_API_KEY'], debugging: logging, production: true)
  ap n3rgy.grant_trusted_consent(mpxn, example_consent_file_link)
end

# parked here temporarily as doesn't work
def grant_new_consent(mpxn, meter)
  n3rgy_consent = MeterReadingsFeeds::N3rgyConsent.new(api_key: meter.api_key, base_url: meter.base_url)
  n3rgy_consent.grant_trusted_consent(mpxn, 'testing sandbox')
end

def command_line_options
  [
    { arg: '-mpxn',     args: 1, var: :mpxns, parse: 'mpxn_split_list', help: 'comma separated list' },
    { arg: '-all',      args: 0, var: :all_meters },
    { arg: '-data',     args: 0, var: :download_data },
    { arg: '-monitor',  args: 0, var: :monitor },
    { arg: '-consent',  args: 0, var: :consent },
    { arg: '-dates',  args: 0,   var: :dates },
    { arg: '-available_meters',   args: 0, var: :available_meters }
  ]
end

def mpxn_split_list(list)
  list.split(',').map(&:to_i)
end

cmd = ParseCommandLine.new(command_line_options)
cmd.parse

mpxns = cmd.all_meters ? DCCMeters.all_mpxns : cmd.mpxns
mpxns.each do |mpxn|
  meter = DCCMeters.meter(mpxn)
  n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: meter.api_key, base_url: meter.base_url)
  if n3rgy_data.status(mpxn) == :consent_required && cmd.consent
    grant_new_consent(mpxn, meter)
  end
  if cmd.dates
    start_date = n3rgy_data.cache_start_datetime(mpxn: mpxn, fuel_type: meter.fuel_type)
    end_date   = n3rgy_data.cache_end_datetime(mpxn: mpxn, fuel_type: meter.fuel_type)
    puts "#{mpxn} #{start_date} #{end_date}"
  end
end

exit

ap DCCMeters.available_meters if cmd.available_meters

monitor(cmd.mpxns, cmd) if cmd.monitor
