require_relative '../lib/dashboard.rb'

def log(in_str)
  str = DateTime.now.strftime('%H:%m:%S: ') + in_str
  puts str
  open('./Results/n3rgy mpan log.text', 'a') { |f|
    f.puts str
  }
end

def save_csv(fuel_type, readings)
  filename1 = './Results/n3rgy mpan data ' + DateTime.now.strftime('%H %m %S') + '.csv'
  CSV.open(filename1, 'w') do |csv|
    csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
    readings[fuel_type][:readings].each do |date, one_days_readings|
      csv << [date, one_days_readings.one_day_kwh, one_days_readings.kwh_data_x48].flatten
    end
  end

  filename2 = './Results/n3rgy mpan missing data ' + DateTime.now.strftime('%H %m %S') + '.csv'
  CSV.open(filename2, 'w') do |csv|
    readings[fuel_type][:missing_readings].each do |dt|
      csv << [ dt ]
    end
  end
end

def analyse_readings(fuel_type, readings)
  "Readings: #{readings[fuel_type][:readings].length} Missing: #{readings[fuel_type][:missing_readings].length}"
end

test = true
if test
  base_url = 'https://sandboxapi.data.n3rgy.com/'
  mpxn = 2234567891000
  start_date = Date.parse('2018-12-25')
  end_date   = Date.parse('2019-05-15') + 1
  fuel_type = :electricity
else
  base_url = 'https://api.data.n3rgy.com/'
  mpxn = 2234567891000
  end_date = Date.today - 1
  start_date = end_date - 13 * (364 / 12)
  fuel_type = :electricity
end

n3rgy_data = MeterReadingsFeeds::N3rgyData.new(api_key: ENV['N3RGY_API_KEY'], base_url: base_url)

sleep_times = [[10, 60], [60, 60], [600, 24 * 6]]

sleep_times.each do |(sleep_period, count)|
  count.times do
    readings = n3rgy_data.readings(mpxn, fuel_type, start_date, end_date)
    log(analyse_readings(fuel_type, readings))
    save_csv(fuel_type, readings)
    sleep sleep_period
  end
end
