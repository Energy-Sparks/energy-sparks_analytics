require 'date'
require 'logger'

require 'require_all'
require_relative '../lib/dashboard.rb'
require_relative '../test_support/csv_file_support.rb'

class DownloadLowCarbonHubMeterReadings
  attr_reader :rbee
  METER_TYPES = %i[solar_pv electricity exported_solar_pv].freeze

  def initialize(school_name, rbee_meter_id, urn)
    @school_name = school_name
    @low_carbon_hub_meter_id = rbee_meter_id
    @urn = urn
    @low_carbon_hub = LowCarbonHubMeterReadings.new
  end

  def print_school_details
    useful_fields = {
      'name'          => 'installationName',
      'postcode'      => 'zipCode',
      'peak power'    => 'peakPower',
      'orientation'   => 'azimut',
      'slope'         => 'slope',
      '1st conn date' => 'firstConnectionDate',
      'mes date'      => 'mesDate' # not sure what this is, but possibly more reliable than install date?
    }

    useful_fields.each do |field, mapping|
      puts sprintf('%-20.20s %s', field, info[mapping])
    end
  end

  def synthetic_mpans
    RbeeSolarPV::METER_TYPES.map { |type| [type, Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@urn, type)] }.to_h
  end

  def load_yaml_file
    return nil unless File.exist?(filename)
    puts "Loading file from #{filename}"
    YAML.load_file(filename)
  end

  def save_yaml_file
    puts "Saving file to #{filename}"
    File.open(filename, 'w') { |f| f.write(YAML.dump(@meter_readings)) }
  end

  def filename
    File.join(File.dirname(__FILE__), '../MeterReadings/') + "#{@school_name} - energy sparks amr data analytics meter readings.yml"
  end

  def meter_readings
    @meter_readings ||= load_yaml_file
  end

  def merge_in_new_meters_readings(download_data)
    @meter_readings ||= []
    count_before = @meter_readings.length
    download_data.each_value do |data|
      @meter_readings += data[:readings].values
    end
    puts "Had #{count_before} meter readings, now increased to #{@meter_readings.length}"
  end

  def calculate_start_date
    return @low_carbon_hub.first_meter_reading_date(@low_carbon_hub_meter_id) if meter_readings.nil?
    find_latest_meter_reading(synthetic_mpans.values.map(&:to_s)) + 1
  end

  def calculate_end_date
    Date.today - 1
  end

  def find_latest_meter_reading(meter_ids)
    max_date = {}
    meter_readings.each do |one_days_data|
      max_date[one_days_data.meter_id] = max_date.key?(one_days_data.meter_id) ? [max_date[one_days_data.meter_id], one_days_data.date].max : one_days_data.date
    end
    max_dates = meter_ids.map { |meter_id| max_date[meter_id] }
    raise EnergySparksUnexpectedStateException.new, "max dates differ #{max_dates}" if max_dates.uniq.length != 1
    max_dates.uniq.first
  end

  def download(start_date, end_date)
    @low_carbon_hub.download(@low_carbon_hub_meter_id, @urn, start_date, end_date)
  end

  def info
    @installation_information ||= @low_carbon_hub.full_installation_information(@low_carbon_hub_meter_id)
  end
end

def print_all_available_meter_data
  rbee = RbeeSolarPV.new
  list = rbee.available_meter_ids
  list.each do |meter_id|
    puts '=' * 80
    ap rbee.full_installation_information(meter_id)
  end
end

old_request = {
  name:     'Long Furlong',
  meter_id: 216057958,
  urn:      123085
}
request = {
  name:     'Windmill Primary School',
  meter_id: 216057754,
  urn:      9312527
}

# print_all_available_meter_data

low_carbon = DownloadLowCarbonHubMeterReadings.new(request[:name], request[:meter_id], request[:urn])
start_date = low_carbon.calculate_start_date
start_date = Date.new(2016,11,1)
puts "start_date = #{start_date}"
end_date = Date.today - 1
data = low_carbon.download(start_date, end_date) # low_carbon.calculate_end_date)
low_carbon.merge_in_new_meters_readings(data)
low_carbon.save_yaml_file
