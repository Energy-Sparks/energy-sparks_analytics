require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/display energy certificates ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def header
  %i[
    es_name
    es_floor_area
    floor_area
    electricity_kwh
    es_electricity_kwh
    calculated_electricity_kwh
    es_electricity_status
    es_days_electricity_data
    es_electricity_last_reading
    heating_kwh
    es_gas_kwh
    calculated_heating_kwh
    es_gas_status
    es_days_gas_data
    es_gas_last_reading
    renewables_kwh
    date
    address
    name
    postcode
    buildings
    air_conditioning
    renewable_heat_kwh
    renewables_types
    main_heating_fuel
    other_heating_fuel
    rating
    environment
    local_authority_name
  ]
end

def annual_kwh(school, fuel_type, dec_date)
  meter = school.aggregate_meter(fuel_type)
  return {} if meter.nil?

  meter = meter.original_meter

  data = if !dec_date.nil? && dec_date - 365 >= meter.amr_data.start_date && dec_date <= meter.amr_data.end_date
    {
      kwh:              meter.amr_data.kwh_date_range(dec_date - 365, dec_date),
      status:           :matches_dec_dates
    }
  elsif meter.amr_data.days >= 365
    {
      kwh:             meter.amr_data.kwh_date_range(meter.amr_data.end_date - 365, meter.amr_data.end_date),
      status:          :latest_data_only
    }
  else
    {
      kwh:             meter.amr_data.kwh_date_range(meter.amr_data.start_date, meter.amr_data.end_date),
      status:          :partial_year_only
    }
  end

  data.merge! (
    {
      days_meter_data:    meter.amr_data.days,
      last_meter_reading: meter.amr_data.end_date
    }
  )

  data
end

def save_csv(data)
  filename = './Results/display_energy_certificate.csv'
  puts "Saving results to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << header
    data.each do |_school_name, one_school|
      csv << header.map { |key| one_school[key] }
    end
  end
end

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

ap school_names
data = {}

school_names.each do |school_name|
  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  dec_data = DisplayEnergyCertificate.new.recent_aggregate_data(school.postcode)

  dec_date = dec_data.nil? ? nil : dec_data[:date]

  es_electric = annual_kwh(school, :electricity, dec_date)
  es_gas = annual_kwh(school, :gas, dec_date)

  data[school_name] = {
    es_name:                      school_name,
    es_floor_area:                school.floor_area,
    es_electricity_kwh:           es_electric[:kwh],
    es_electricity_status:        es_electric[:status],
    es_days_electricity_data:     es_electric[:days_meter_data],
    es_electricity_last_reading:  es_electric[:last_meter_reading],
    es_gas_kwh:                   es_gas[:kwh],
    es_gas_status:                es_gas[:status],
    es_days_gas_data:             es_gas[:days_meter_data],
    es_gas_last_reading:          es_gas[:last_meter_reading],
  }
  data[school_name].merge!(dec_data) unless dec_data.nil?
end

save_csv(data)
