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

class MeterCollection
  include Logging

  attr_reader :heat_meters, :electricity_meters, :solar_pv_meters, :storage_heater_meters

  # From school/building
  attr_reader :floor_area, :number_of_pupils

  # Currently, but not always
  attr_reader :school, :name, :address, :postcode, :urn, :area_name, :model_cache, :default_energy_purchaser

  # These are things which will be populated
  attr_accessor :aggregated_heat_meters, :aggregated_electricity_meters,
                :electricity_simulation_meter, :storage_heater_meter, :solar_pv_meter,
                :holidays,
                :temperatures,
                :solar_irradiation,
                :solar_pv,
                :grid_carbon_intensity

  def initialize(school, holidays:, temperatures:, solar_irradiation:, solar_pv:, grid_carbon_intensity:, pseudo_meter_attributes: {})
    @name = school.name
    @address = school.address
    @postcode = school.postcode
    @floor_area = school.floor_area
    @number_of_pupils = school.number_of_pupils
    @holidays = holidays
    @temperatures = temperatures
    @solar_irradiation = solar_irradiation
    @solar_pv = solar_pv
    @grid_carbon_intensity = grid_carbon_intensity

    @heat_meters = []
    @electricity_meters = []
    @solar_pv_meters = []
    @storage_heater_meters = []
    @school = school
    @urn = school.urn
    @meter_identifier_lookup = {} # [mpan or mprn] => meter
    @area_name = school.area_name
    @default_energy_purchaser = @area_name # use the area name for the moment
    @aggregated_heat_meters = nil
    @aggregated_electricity_meters = nil
    @pseudo_meter_attributes = pseudo_meter_attributes

    @cached_open_time = TimeOfDay.new(7, 0) # for speed
    @cached_close_time = TimeOfDay.new(16, 30) # for speed
  end

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

  def aggregate_meter(fuel_type)
    case fuel_type
    when :electricity
      aggregated_electricity_meters
    when :gas
      aggregated_heat_meters
    when :storage_heater, :storage_heaters
      storage_heater_meter
    when :solar_pv
      solar_pv_meter
    end
  end

  def to_s
    'Meter Collection:' + name + ':' + all_meters.join(';')
  end

  def meter?(identifier, search_sub_meters = false)
    identifier = identifier.to_s # ids coulld be integer or string
    return @meter_identifier_lookup[identifier] if @meter_identifier_lookup.key?(identifier)

    meter = search_meter_list_for_identifier(all_meters, identifier)
    unless meter.nil?
      @meter_identifier_lookup[identifier] = meter
      return meter
    end

    if search_sub_meters
      all_meters.each do |meter|
        sub_meter = search_meter_list_for_identifier(meter.sub_meters, identifier)
        unless sub_meter.nil?
          @meter_identifier_lookup[identifier] = sub_meter
          return sub_meter
        end
      end
    end

    @meter_identifier_lookup[identifier] = nil
    nil
  end

  private def search_meter_list_for_identifier(meter_list, identifier)
    return nil if identifier.nil?
    meter_list.each do |meter|
      return nil if meter.id.nil?
      return meter if meter.id.to_s == identifier.to_s
    end
    nil
  end

  def all_meters
    meter_groups = [
      @heat_meters,
      @electricity_meters,
      @solar_pv_meters,
      @storage_heater_meters,
      @aggregated_heat_meters,
      @aggregated_electricity_meters
    ]

    meter_list = []
    meter_groups.each do |meter_group|
      unless meter_group.nil?
        meter_list += meter_group.is_a?(Dashboard::Meter) ? [meter_group] : meter_group
      end
    end
    meter_list.uniq{ |meter| meter.mpan_mprn } # for single meter schools aggregate and meter can be one and the same
  end

  # some meters are 'artificial' e.g. split off storage meters and re aggregated solar PV meters
  def real_meters
    all_meters.select { |meter| !meter.synthetic_mpan_mprn? }
  end

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

  def report_group
    if !aggregated_heat_meters.nil?
      if !aggregated_electricity_meters.nil?
        solar_pv_panels? ? :electric_and_gas_and_solar_pv : :electric_and_gas
      else
        :gas_only
      end
    else
      if solar_pv_panels?
        :electric_and_solar_pv
      elsif storage_heaters?
        :electric_and_storage_heaters
      else
        :electric_only
      end
    end
  end

  def all_heat_meters
    all_meters.select { |meter| meter.heat_meter? }
  end

  def all_electricity_meters
    all_meters.select { |meter| meter.electricity_meter? }
  end

  def all_real_meters
    [all_heat_meters, all_electricity_meters].flatten
  end

  def gas_only?
    all_meters.select { |meter| meter.electricity_meter? }.empty?
  end

  def non_heating_only?
    all_heat_meters.all? { |meter| meter.non_heating_only? }
  end

  def heating_only?
    all_heat_meters.all? { |meter| meter.heating_only? }
  end

  def electricity?
    !aggregated_electricity_meters.nil?
  end

  def gas?
    !aggregated_heat_meters.nil?
  end

  def storage_heaters?
    @has_storage_heaters ||= all_meters.any?{ |meter| meter.storage_heater? }
  end

  def all_aggregate_meters
    [
      electricity? ? aggregated_electricity_meters : nil,
      gas? ? aggregated_heat_meters : nil,
      storage_heaters? ? storage_heater_meter : nil
    ].compact
  end

  def solar_pv_panels?
    sheffield_simulated_solar_pv_panels? || low_carbon_solar_pv_panels?
  end

  def fuel_types(exclude_storage_heaters = true)
    types = []
    types.push(:electricity)      if electricity?
    types.push(:gas)              if gas?
    types.push(:storage_heaters)  if storage_heaters? && !exclude_storage_heaters
    types
  end

  def sheffield_simulated_solar_pv_panels?
    @has_sheffield_simulated_solar_pv_panels ||= all_meters.any?{ |meter| meter.sheffield_simulated_solar_pv_panels? }
  end

  def low_carbon_solar_pv_panels?
    @has_low_carbon_hub_solar_pv_panels ||= all_meters.any?{ |meter| meter.low_carbon_hub_solar_pv_panels? }
  end

  def school_type
    @school.nil? ? nil : @school.school_type
  end

  def add_heat_meter(meter)
    @heat_meters.push(meter)
    @meter_identifier_lookup[meter.id] = meter
  end

  def add_electricity_meter(meter)
    @electricity_meters.push(meter)
    @meter_identifier_lookup[meter.id] = meter
  end

  def add_aggregate_heat_meter(meter)
    @aggregated_heat_meters = meter
    @meter_identifier_lookup[meter.id] = meter
  end

  def add_aggregate_electricity_meter(meter)
    @aggregated_electricity_meters = meter
    @meter_identifier_lookup[meter.id] = meter
  end

  def open_time
    @cached_open_time
  end

  def close_time
    @cached_close_time
  end

  def pseudo_meter_attributes(type)
    @pseudo_meter_attributes.fetch(type){ {} }
  end

  # This is overridden in the energysparks code at the moment, to use the actual open/close times
  # It replaces school_day_in_hours(time_of_day)
  def is_school_usually_open?(_date, time_of_day)
    time_of_day >= @cached_open_time && time_of_day < @cached_close_time
  end
end
