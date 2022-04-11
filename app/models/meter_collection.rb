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

  attr_reader :heat_meters, :electricity_meters, :storage_heater_meters

  # From school/building
  attr_reader :floor_area, :number_of_pupils

  # Currently, but not always
  attr_reader :school, :name, :address, :postcode, :urn, :area_name, :model_cache, :default_energy_purchaser

  # These are things which will be populated
  attr_accessor :aggregated_heat_meters, :aggregated_electricity_meters,
                :electricity_simulation_meter, :storage_heater_meter,
                :holidays,
                :temperatures,
                :solar_irradiation,
                :solar_pv,
                :grid_carbon_intensity

  # Centrica
  attr_accessor :aggregated_electricity_meter_without_community_usage
  attr_accessor :aggregated_heat_meters_without_community_usage
  attr_accessor :storage_heater_meter_without_community_usage
  attr_accessor :community_disaggregator

  def initialize(school, holidays:, temperatures:, solar_irradiation: nil, solar_pv:, grid_carbon_intensity:, pseudo_meter_attributes: {})
    @name = school.name
    @address = school.address
    @postcode = school.postcode
    @floor_area = school.floor_area
    @number_of_pupils = school.number_of_pupils
    @holidays = holidays
    @temperatures = temperatures
    @solar_pv = solar_pv
    @solar_irradiation = solar_irradiation.nil? ? SolarIrradianceFromPV.new('solar irradiance from pv', solar_pv_data: solar_pv) : solar_irradiation

    @grid_carbon_intensity = grid_carbon_intensity

    unless school.location.nil?
      @latitude  = school.location[0].to_f
      @longitude = school.location[1].to_f
    end

    @heat_meters = []
    @electricity_meters = []
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
    process_school_times(school.school_times, school.community_use_times)
  end

  def merge_additional_pseudo_meter_attributes(pseudo_meter_attributes)
    @pseudo_meter_attributes = @pseudo_meter_attributes.deep_merge(pseudo_meter_attributes)
  end

  def delete_pseudo_meter_attribute(pseudo_meter_key, attribute_key)
    @pseudo_meter_attributes[pseudo_meter_key]&.delete(attribute_key)
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
      aggregated_electricity_meters.sub_meters[:generation]
    end
  end

  def sheffield_solar_pv_data
    solar_pv
  end

  def set_aggregate_meter(fuel_type, meter)
    case fuel_type
    when :electricity
      @aggregated_electricity_meters = meter
    when :gas
      @aggregated_heat_meters = meter
    when :storage_heater, :storage_heaters
      @storage_heater_meter = meter
    when :solar_pv
      @aggregated_electricity_meters.sub_meters[:generation] = meter
    end
  end

  def set_aggregate_meter_non_community_use_meter(fuel_type, meter)
    case fuel_type
    when :electricity
      puts "Got here setting non community use electricity meter"
      @aggregated_electricity_meter_without_community_usage = meter
    when :gas
      puts "Got here setting non community use gas meter"
      @aggregated_heat_meters_without_community_usage = meter
    when :storage_heater, :storage_heaters
      @storage_heater_meter_without_community_usage = meter
    end
  end

  def update_electricity_meters(electricity_meter_list)
    @electricity_meters = electricity_meter_list
  end

  def aggregated_unaltered_electricity_meters
    aggregated_electricity_meters.sub_meters.fetch(:mains_consume, aggregated_electricity_meters)
  end

  # attr_reader/@floor_area is set by the front end
  # if there are relevant pseudo meter attributes
  # override it with a calculated value
  def floor_area(start_date = nil, end_date = nil)
    calculate_floor_area_number_of_pupils
    @calculated_floor_area_pupil_numbers.floor_area(start_date, end_date)
  end

  def number_of_pupils(start_date = nil, end_date = nil)
    calculate_floor_area_number_of_pupils
    @calculated_floor_area_pupil_numbers.number_of_pupils(start_date, end_date)
  end

  # somewhat approx, imperfect solutjon to determine 3rd lcokdown periods without external JSON call
  def country
    scotland_postcodes = %w[AB DD DG EH FK G HS IV KA KW KY ML PA PH TD ZE]
    wales_postcodes    = %w[CF CH GL HR LD LL NP SA SY]
    postcode_prefix = postcode.upcase[/^[[:alpha:]]+/]

    return :scotland if scotland_postcodes.include?(postcode_prefix)

    if wales_postcodes.include?(postcode_prefix)
      if postcode_prefix == 'SY'
        return postcode.upcase[/[[:digit:]]+/].to_i < 15 ? :england : :wales
      else
        return :wales
      end
    end

    :england
  end

  # temporary, pending being captured by front end
  def funding_status
    [
      10076,
      100076,
      100509,
      100648,
      100756,
      100757,
      101072,
      101845,
      102452,
      102692,
      107166,
      108538,
      109348,
      116581,
      121241,
      122936,
      123310,
      123620,
      131166,
      135174,
      306983,
      402018,
      402019,
      823310,
      900648,
      901954,
      923310,
      3916001
    ].include?(urn) ? :private : :state
  end

  def calculate_floor_area_number_of_pupils
    @calculated_floor_area_pupil_numbers ||= FloorAreaPupilNumbers.new(@floor_area, @number_of_pupils, pseudo_meter_attributes(:school_level_data))
  end

  def first_combined_meter_date
    all_aggregate_meters.map{ |meter| meter.amr_data.start_date }.max
  end

  def last_combined_meter_date
    all_aggregate_meters.map{ |meter| meter.amr_data.end_date }.min
  end

  def inspect
    "Meter Collection (name: '#{@name}', object_id: #{"0x00%x" % (object_id << 1)})"
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
        sub_meter = search_meter_list_for_identifier(meter.all_sub_meters, identifier)
        unless sub_meter.nil?
          @meter_identifier_lookup[identifier] = sub_meter
          return sub_meter
        end
      end
    end

    @meter_identifier_lookup[identifier] = nil
    nil
  end

  def latitude
    @latitude ||= latitude_longitude[:latitude]
  end

  def longitude
    @longitude ||= latitude_longitude[:longitude]
  end

  private def latitude_longitude
    @latitude_longitude ||= LatitudeLongitude.schools_latitude_longitude(self)
  end

  private def search_meter_list_for_identifier(meter_list, identifier)
    return nil if identifier.nil?
    meter_list.each do |meter|
      next if meter.id.nil?
      return meter if meter.id.to_s == identifier.to_s
    end
    nil
  end

  def all_meters(ensure_unique = true, include_sub_meters = true)
    meter_list = [
      @heat_meters,
      @electricity_meters,
      @storage_heater_meters,
      @aggregated_heat_meters,
      @aggregated_electricity_meters
    ].compact.flatten

    meter_list += meter_list.map { |m| m.sub_meters.values.compact } if include_sub_meters

    meter_list.flatten!

    meter_list.uniq!{ |meter| meter.mpan_mprn } if ensure_unique

    meter_list
  end

  # alternative approach to finding real meters, avoids synthetic_mpan_mprn?
  # which can pickup real meters coming in from 3rd party systems like
  # Orsis where the MPAN is made up; used to test whether this approach works
  #  too big a change to replace real_meters function
  # TODO (PH, 4May2021) - replace if working, fully tested - see costs_advice.rb: check_real_meters
  def real_meters2
    meter_list = [
      @heat_meters,
      @electricity_meters,
      @storage_heater_meters
    ].compact.flatten

    meters = meter_list.map{ |m| m.sub_meters.fetch(:mains_consume, m) }

    meters.uniq{ |meter| meter.mpxn }
  end

  # some meters are 'artificial' e.g. split off storage meters and re aggregated solar PV meters
  def real_meters
    all_meters.select { |meter| !meter.synthetic_mpan_mprn? }.uniq{ |m| m.mpxn}
  end

  def underlying_meters(fuel_type)
    case fuel_type
    when :electricity
      @electricity_meters
    when :gas
      @heat_meters
    when :storage_heater
      @storage_heater_meters
    else
      []
    end
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
    report_groups.push(:carbon_group)                 # if electricity? && gas?
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

  def solar_pv_panels?
    @solar_pv_panels ||= all_meters.any?{ |meter| meter.solar_pv_panels? }
  end

  def sheffield_simulated_solar_pv_panels?
    @sheffield_simulated_solar_pv_panels ||= all_meters.any?{ |meter| meter.sheffield_simulated_solar_pv_panels? }
  end

  def solar_pv_real_metering?
    @solar_pv_real_metering ||= all_meters.any?{ |meter| meter.solar_pv_real_metering? }
  end

  def solar_pv_and_or_storage_heaters?
    storage_heaters? || solar_pv_panels?
  end

  def all_aggregate_meters
    [
      electricity? ? aggregated_electricity_meters : nil,
      gas? ? aggregated_heat_meters : nil,
      storage_heaters? ? storage_heater_meter : nil
    ].compact
  end

  def community_usage?
    open_close_times.community_usage?
  end

  def fuel_types(exclude_storage_heaters = true, exclude_solar_pv = true)
    types = []
    types.push(:electricity)      if electricity?
    types.push(:gas)              if gas?
    types.push(:storage_heaters)  if storage_heaters? && !exclude_storage_heaters
    types.push(:solar_pv)         if solar_pv_panels? && !exclude_solar_pv
    types
  end

  def school_type
    @school.nil? ? nil : @school.school_type
  end

  def energysparks_start_date
    activation_date.nil? ? creation_date : activation_date
  end

  def activation_date
    return nil if @school.nil?
    return nil if @school.activation_date.nil?
    # the time is passed in as an active_support Time and not a ruby Time
    # from the front end, so can't be used directly, the utc field needs to be accessed
    # instead
    t = @school.activation_date.respond_to?(:utc) ? @school.activation_date.utc : @school.activation_date
    Date.new(t.year, t.month, t.day)
  end

  def creation_date
    return nil if @school.nil?
    return nil if @school.created_at.nil?
    # the time is passed in as an active_support Time and not a ruby Time
    # from the front end, so can't be used directly, the utc field needs to be accessed
    # instead
    t = @school.created_at.respond_to?(:utc) ? @school.created_at.utc : @school.created_at
    Date.new(t.year, t.month, t.day)
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

  def open_close_times
    @open_close_times ||= OpenCloseTimes.new(pseudo_meter_attributes(:school_level_data), holidays)
  end

  def process_school_times(school_day_times, community_times)
    if school_day_times.nil? # TODO(PH, 17Feb2022) remove once new school timing code has migrated to production, backwards compatibility with old YAML files
      @open_close_times = OpenCloseTimes.default_school_open_close_times(holidays)
    else
      @open_close_times = OpenCloseTimes.convert_frontend_times(school_day_times, community_times, holidays)
    end
  end

  def target_school(type = :day)
    @target_school ||= {}
    @target_school[type] ||= TargetSchool.new(self, type)
  end

  def benchmark_school(benchmark_type = :benchmark)
    @benchmark_school ||= {}
    @benchmark_school[benchmark_type] ||= BenchmarkSchool.new(self, benchmark_type: benchmark_type)
  end

  def reset_target_school_for_testing(type = :day)
    puts "Resetting target school #{name}"
    @target_school.delete(type) unless @target_school.nil?
  end

  def pseudo_meter_attributes(type)
    @pseudo_meter_attributes.fetch(type){ {} }
  end

  def pseudo_meter_attributes_private
    @pseudo_meter_attributes
  end

  def meter_attribute_types
    @pseudo_meter_attributes.keys
  end

  # This is overridden in the energysparks code at the moment, to use the actual open/close times
  # It replaces school_day_in_hours(time_of_day)
  def is_school_usually_open?(_date, time_of_day)
    time_of_day >= @cached_open_time && time_of_day < @cached_close_time
  end
end
