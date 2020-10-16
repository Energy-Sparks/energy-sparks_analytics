require 'digest'
require 'net/http'
require 'json'
require 'amazing_print'
require 'date'
require 'csv'

class SolarEdgeSolarPV
  def initialize(api_key = ENV['ENERGYSPARKSSOLAREDGEAPIKEY'])
    @api_key = api_key
  end

  def site_details
    @site_details ||= json_query(set_details_url)
  end

  def site_ids
    sites.map{ |site| site['id'] }
  end

  def sites
    site_details['sites']['site']
  end

  def site_start_end_dates(site_id)
    dates = json_query(meter_start_end_dates_url(site_id))
    [Date.parse(dates['dataPeriod']['startDate']), Date.parse(dates['dataPeriod']['endDate'])]
  end

  def json_query(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def meter_readings(meter_id, start_date, end_date)
    raw_data = raw_meter_readings(meter_id, start_date, end_date)

    dt_to_kwh = raw_data.map{ |h| [date(h['date']) , (h['value'] || 0.0) / 1000.0]}.to_h

    missing_readings = []
    readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) }

    (start_date..end_date).each do |date|
      (0..23).each do |hour|
        [0, 30].each_with_index do |mins30, hh_index|
          [0, 15].each do |mins15|
            dt = datetime_to_15_minutes(date, hour, mins30 + mins15)
            if dt_to_kwh.key?(dt)
              readings[date][hour * 2 + hh_index] += dt_to_kwh[dt]
            else
              missing_readings.push(dt)
            end
          end
        end
      end
    end
    {
      readings:         readings,
      missing_readings: missing_readings
    }
  end

  def save_readings_to_csv(readings)
    filename = 'Results\Solar Edge Freshford School.csv'
    puts "Saving readings to #{filename}"
    CSV.open(filename, 'w') do |csv|
      csv << ['date', 'days kWh', (0..47).map{ |hh| "#{(hh / 2).to_i}:#{(hh % 2) * 30}"}].flatten
      readings.each do |date, kwh_x48|
        csv << [date, kwh_x48.sum, kwh_x48].flatten
      end
    end
  end

  def datetime_to_15_minutes(date, hour, mins)
    dt = DateTime.new(date.year, date.month, date.day, hour, mins, 0)
    t = dt.to_time + 0
    DateTime.new(t.year, t.month, t.day, t.hour, t.min, t.sec)
  end

  def date(date_string)
    DateTime.parse(date_string)
  end

  def raw_meter_readings(meter_id, start_date, end_date)
    data = []
    (start_date..end_date).each_slice(28) do |twenty_eight_days| # api limit of 1 month
      data.push(raw_meter_readings_28_days_max(meter_id, twenty_eight_days.first, twenty_eight_days.last))
    end
    data.flatten
  end

  def raw_meter_readings_28_days_max(meter_id, start_date, end_date)
    json_query(raw_meter_data_url(meter_id, start_date, end_date))['energy']['values']
  end

  def set_details_url
    'https://monitoringapi.solaredge.com/sites/list?size=5&searchText=Lyon&sortProperty=name&sortOrder=ASC&api_key=' + @api_key
  end

  def meter_start_end_dates_url(meter_id)
    'https://monitoringapi.solaredge.com/site/' + meter_id.to_s + '/dataPeriod?api_key='  + @api_key
  end

  def raw_meter_data_url(meter_id, start_date, end_date)
    'https://monitoringapi.solaredge.com/site/' + meter_id.to_s + '/energy?timeUnit=QUARTER_OF_AN_HOUR' +
    '&endDate=' + end_date.to_s + '&startDate=' + start_date.to_s + '&api_key='  + @api_key
  end
end

solar = SolarEdgeSolarPV.new
ap solar.site_details
ap solar.site_ids
solar.site_ids.each do |site_id|
  puts "Site id = #{site_id}"
  start_date, end_date = solar.site_start_end_dates(site_id)
  readings = solar.meter_readings(site_id, start_date, end_date)
  solar.save_readings_to_csv(readings[:readings])
end