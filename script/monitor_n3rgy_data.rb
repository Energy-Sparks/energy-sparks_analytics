require_relative '../lib/dashboard.rb'

class DCCMeters
  def available_meters
    @available_meters ||= {
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
      2234567891001 => {},
      2000006185057 => { production: true},
      2200015678553 => { production: true},
    }
  end

  def api_key(mpxn)
    production(mpxn) ? ENV['N3RGY_API_KEY'] : ENV['N3RGY_SANDBOX_API_KEY']
  end

  def base_url(mpxn)
    production(mpxn) ? 'https://api.data.n3rgy.com/' : 'https://sandboxapi.data.n3rgy.com/'
  end

  private
  
  def production(mpxn)
    available_meters.key?(mpxn) && available_meters[mpxn]
  end
end

def log(in_str)
  str = DateTime.now.strftime('%H:%M:%S: ') + in_str
  puts str
  open('./Results/n3rgy mpan log.text', 'a') { |f|
    f.puts str
  }
end

def save_csv(fuel_type, readings)
  filename1 = './Results/n3rgy mpan data ' + DateTime.now.strftime('%H %M %S') + '.csv'
  CSV.open(filename1, 'w') do |csv|
    csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings[fuel_type][:readings].each do |date, one_days_readings|
      csv << [date, one_days_readings.one_day_kwh, one_days_readings.kwh_data_x48].flatten
    end
  end

  filename2 = './Results/n3rgy mpan missing data ' + DateTime.now.strftime('%H %M %S') + '.csv'
  CSV.open(filename2, 'w') do |csv|
    readings[fuel_type][:missing_readings].each do |dt|
      csv << [ dt ]
    end
  end
end

def analyse_readings(fuel_type, readings)
  "Readings: #{readings[fuel_type][:readings].length} Missing: #{readings[fuel_type][:missing_readings].length}"
end

mpxn = 2200015678553

api_key     = DCCMeters.new.api_key(mpxn)
base_url    = DCCMeters.new.base_url(mpxn)
end_date    = Date.today
start_date  = end_date - 13 * (364 / 12)
fuel_type = :electricity
logging = { puts: true, ap: { limit: 5 } }

n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: api_key, base_url: base_url)

sleep_times = [[10, 60], [60, 60], [600, 24 * 6]]

sleep_times.each do |(sleep_period, count)|
  count.times do
    begin
      readings = n3rgy_data.readings(mpxn, fuel_type, start_date, end_date)
      log(analyse_readings(fuel_type, readings))
      save_csv(fuel_type, readings)
    rescue => e
      puts e.message
    end
    sleep sleep_period
  end
end
