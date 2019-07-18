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
                :schedule_data_manager

  def initialize(school, schedule_data_manager)
    @name = school.name
    @address = school.address
    @postcode = school.postcode
    @floor_area = school.floor_area
    @number_of_pupils = school.number_of_pupils
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
    @schedule_data_manager = schedule_data_manager

    @cached_open_time = TimeOfDay.new(7, 0) # for speed
    @cached_close_time = TimeOfDay.new(16, 30) # for speed

    configure_schedule_names
  end

  def configure_schedule_names
    # Normally these would come from the school, hard coded at the mo
    @holiday_schedule_name = school.area_name.nil? ? @schedule_data_manager::BATH_AREA_NAME : school.area_name
    @temperature_schedule_name = school.area_name.nil? ? @schedule_data_manager::BATH_AREA_NAME : school.area_name
    @solar_irradiance_schedule_name = school.area_name.nil? ? @schedule_data_manager::BATH_AREA_NAME : school.area_name
    @solar_pv_schedule_name = school.area_name.nil? ? @schedule_data_manager::BATH_AREA_NAME : school.area_name
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

  def to_s
    'Meter Collection:' + name + ':' + all_meters.join(';')
  end

  def meter?(identifier)
    identifier = identifier.to_s # ids coulld be integer or string
    return @meter_identifier_lookup[identifier] if @meter_identifier_lookup.key?(identifier)

    all_meters.each do |meter|
      if meter.id.to_s == identifier
        @meter_identifier_lookup[identifier] = meter
        return meter
      end
    end
    @meter_identifier_lookup[identifier] = nil
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

  def report_group
    heat_report = !all_heat_meters.nil?
    electric_report = !all_electricity_meters.nil?
    if heat_report && electric_report
      :electric_and_gas
    elsif heat_report
      :gas_only
    elsif electric_report
      if solar_pv_panels?
        :electric_and_solar_pv
      else
        :electric_only
      end
    else
      nil
    end
  end

  def all_heat_meters
    all_meters.select { |meter| meter.heat_meter? }
  end

  def all_electricity_meters
    all_meters.select { |meter| meter.electricity_meter? }
  end

  def gas_only?
    all_meters.select { |meter| meter.electricity_meter? }.empty?
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
    @has_solar_pv_panels ||= all_meters.any?{ |meter| meter.solar_pv_panels? }
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

  # This is overridden in the energysparks code at the moment, to use the actual open/close times
  # It replaces school_day_in_hours(time_of_day)
  def is_school_usually_open?(_date, time_of_day)
    time_of_day >= @cached_open_time && time_of_day < @cached_close_time
  end

  # held at building level as a school building e.g. a community swimming pool may have a different holiday schedule
  def holidays
    @schedule_data_manager.holidays(@holiday_schedule_name)
  end

  def temperatures
    @schedule_data_manager.temperatures(@temperature_schedule_name)
  end

  def solar_irradiation
    @schedule_data_manager.solar_irradiation(@solar_irradiance_schedule_name)
  end

  def solar_pv
    @schedule_data_manager.solar_pv(@solar_pv_schedule_name)
  end

  def grid_carbon_intensity
    @schedule_data_manager.uk_grid_carbon_intensity
  end
end
