# Was a building!

# building: potentially a misnomer, holds data associated with a group
#           of buildings, which could be a whole school or the area
#           covered by a single meter
#           primarily a placeholder for data associated with a school
#           or group of buildings, potentially different to the parent
#           school, so for example a different holiday and open/close time
#           schedule if a meter covers a community sports centre which is
#           used out of core school hours
#           - also holds modelling data

require 'active_support/core_ext/module/delegation'

class MeterCollection
  include Logging

  delegate :number_of_pupils, :address, :name, :postcode, :floor_area, :area_name, :urn, to: :school

  delegate :all_meters, :real_meters, :all_heat_meters, :all_heat_meters, :all_real_meters, :gas_only?, :report_group, to: :meter_data
  delegate :non_heating_only?, :heating_only?, to: :meter_data
  delegate :sheffield_simulated_solar_pv_panels?, :low_carbon_solar_pv_panels?, :electricity?, :gas?, :storage_heaters?, :all_aggregate_meters?, :solar_pv_panels?, to: :meter_data
  delegate :aggregated_heat_meters, :aggregated_electricity_meters, :electricity_simulation_meter, :storage_heater_meter, :solar_pv_meter, to: :meter_data
  delegate :aggregated_heat_meters=, :aggregated_electricity_meters=, :electricity_simulation_meter=, :storage_heater_meter=, :solar_pv_meter=, to: :meter_data
  delegate :heat_meters, :electricity_meters, :solar_pv_meters, :storage_heater_meters, :all_aggregate_meters, to: :meter_data

  attr_reader :school, :model_cache, :default_energy_purchaser
  attr_reader :pseudo_meter_attributes

  # These are things which will be populated
  attr_accessor :holidays, :temperatures, :solar_irradiation, :solar_pv, :grid_carbon_intensity, :meter_data

  def initialize(school, holidays:, temperatures:, solar_irradiation:, solar_pv:, grid_carbon_intensity:, pseudo_meter_attributes: {})
    @holidays = holidays
    @temperatures = temperatures
    @solar_irradiation = solar_irradiation
    @solar_pv = solar_pv
    @grid_carbon_intensity = grid_carbon_intensity

    @school = school
    @urn = school.urn
    @default_energy_purchaser = area_name # use the area name for the moment
    @pseudo_meter_attributes = pseudo_meter_attributes

    @meter_data = Dashboard::MeterData.new(pseudo_meter_attributes: @pseudo_meter_attributes)

    @cached_open_time = TimeOfDay.new(7, 0) # for speed
    @cached_close_time = TimeOfDay.new(16, 30) # for speed
  end

  def to_s
    'Meter Collection:' + name + ':' + all_meters.join(';')
  end

  def school_type
    @school.nil? ? nil : @school.school_type
  end

  # This method only used when loading school and meta data
  def matches_identifier?(identifier, identifier_type)
    case identifier_type
    when :name
      identifier == name
    when :urn
      identifier == urn
    when :postcode
      identifier == postcode
    else
      raise EnergySparksUnexpectedStateException.new("Unexpected nil school identifier_type") if identifier_type.nil?
      raise EnergySparksUnexpectedStateException.new("Unknown or implement school identifier lookup #{identifier_type}")
    end
  end

  def open_time
    @cached_open_time
  end

  def close_time
    @cached_close_time
  end

  def is_school_usually_open?(_date, time_of_day)
    time_of_day >= @cached_open_time && time_of_day < @cached_close_time
  end

  # This method is only used in test scripts
  def adult_report_groups
    report_groups = []
    report_groups.push(:benchmark)                    if electricity? && !solar_pv_panels?
    report_groups.push(:benchmark_kwh_electric_only)  if electricity? && solar_pv_panels?
    report_groups.push(:electric_group)               if electricity?
    report_groups.push(:gas_group)                    if gas?
    report_groups.push(:hotwater_group)               unless heating_only?
    report_groups.push(:boiler_control_group)         unless non_heating_only?
    report_groups.push(:storage_heater_group)         if storage_heaters?
    # now part of electricity report_groups.push(:solar_pv_group)               if solar_pv_panels?
    report_groups.push(:carbon_group)                 if electricity? && gas?
    report_groups.push(:energy_tariffs_group)         if false
    report_groups
  end

  # Delegate all these to meter data manually as they have parameters
  def meter?(identifier, search_sub_meters = false)
    @meter_data.meter?(identifier, search_sub_meters)
  end

  def fuel_types(exclude_storage_heaters = true)
    @meter_data.fuel_types(exclude_storage_heaters)
  end

  def aggregate_meter(fuel_type)
    @meter_data.aggregate_meter(fuel_type)
  end

  def add_heat_meter(meter)
    @meter_data.add_heat_meter(meter)
  end

  def add_electricity_meter(meter)
    @meter_data.add_electricity_meter(meter)
  end

  def add_aggregate_heat_meter(meter)
    @meter_data.add_aggregate_heat_meter(meter)
  end

  def add_aggregate_electricity_meter(meter)
    @meter_data.add_aggregate_electricity_meter(meter)
  end

  def pseudo_meter_attributes(type)
    @meter_data.pseudo_meter_attributes(type)
  end
end
