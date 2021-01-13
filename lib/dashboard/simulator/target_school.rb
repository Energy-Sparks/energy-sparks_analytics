require 'require_all'
# creates a 'target' school from an existing school
# the initial implementation is the school with the
# and data shifted 1 year and then scaled by the target factor
# with an attempt to correct for holidays, but set on a per month basis
class TargetSchool < MeterCollection
  include Logging
  def initialize(school, calculation_type)
    super(school.school, holidays: school.holidays, temperatures: school.temperatures,
            solar_irradiation: school.temperatures, solar_pv: school.solar_pv,
            grid_carbon_intensity: school.grid_carbon_intensity,
            pseudo_meter_attributes: school.pseudo_meter_attributes_private)
    @original_school = school
    @aggregated_heat_meters         = school.aggregated_heat_meters
    @aggregated_electricity_meters  = TargetMeter.calculation_factory(calculation_type, school.aggregated_electricity_meters)
    @storage_heater_meter           = storage_heater_meter
    @name += ': target'
  end
end

class TargetAttributes
  attr_reader :attributes
  def initialize(meter)
    @attributes = nil
    unless meter.attributes(:targeting_and_tracking).nil?
      @attributes = meter.attributes(:targeting_and_tracking).sort { |a,b| a[:start_date] <=> b[:start_date] } 
    end
  end

  def target_date_ranges
    @target_date_ranges ||= convert_target_date_ranges
  end

  def target(date)
    # don't use date_range.include? or cover? as 500 times slower than:
    target_date_ranges.select{ |date_range, _target| date >= date_range.first && date <= date_range.last }.values[0]
  end

  def first_target_date
    @attributes[0][:start_date]
  end

  private

  def convert_target_date_ranges
    h = {}
    h[Date.new(2000, 1, 1)..(attributes[0][:start_date] - 1)] = 1.0
    last_index = attributes.length - 1
    (0...last_index).each do |interim_index|
      h[attributes[interim_index][:start_date]..Date.new(2050, 1, 1)] = attributes[interim_index][:target]
    end
    h[attributes[last_index][:start_date]..Date.new(2050, 1, 1)] = attributes[last_index][:target]
    h
  end
end

class TargetMeter < Dashboard::Meter
  include Logging
  def initialize(meter_to_clone)
    super(
      meter_collection: meter_to_clone.meter_collection,
      amr_data: nil,
      type: meter_to_clone.meter_type,
      name: meter_to_clone.name,
      identifier: meter_to_clone.id,
      floor_area: meter_to_clone.floor_area,
      number_of_pupils: meter_to_clone.number_of_pupils,
      solar_pv_installation: meter_to_clone.solar_pv_setup,
      storage_heater_config: meter_to_clone.storage_heater_setup,
      meter_attributes: meter_to_clone.meter_attributes
    )
    @original_meter = meter_to_clone
    @target = TargetAttributes.new(meter_to_clone)
    bm = Benchmark.realtime {
      @amr_data = create_target_amr_data(meter_to_clone)
    }
    calc_text = "Calculated target meter #{mpan_mprn} in #{bm.round(3)} seconds"
    puts calc_text
    puts "Got here total = #{@amr_data.total} kwh"
    logger.info calc_text
  end

  def self.calculation_factory(type, meter_to_clone)
    case type
    when :month
      TargetMeterMonthlyDayType.new(meter_to_clone)
    when :day
      TargetMeterDailyDayType.new(meter_to_clone)
    else
      raise EnergySparksUnexpectedStateException, "Unexpected target averaging type #{type}"
    end
  end

  private

  def create_target_amr_data(meter_to_clone)
    start_date = @target.first_target_date
    end_date   = meter_to_clone.amr_data.end_date + 363

    amr_data = AMRData.new(meter_to_clone.meter_type)
    (start_date..end_date).each do |date|
      # once a years worth of target data has been created then the target is compounded
      # e.g. for a 95% target, year 1 is 95%, year 2 95%^2 etc.
      clone_date = date - 364
      clone_amr_data = amr_data.date_exists?(clone_date) ? amr_data : meter_to_clone.amr_data
      clone_kwh_x48 = clone_amr_data.one_days_data_x48(clone_date)
      target_kwh_x48 = target_amr_data(clone_kwh_x48, date, clone_date, clone_amr_data)
      amr_data.add(date, target_kwh_x48)
    end
    amr_data
  end
end

# calculates average profiles per month from previous year
# and then applies a scalar target reduction to them
# takes about 24ms per 365 days to calculate
class TargetMeterMonthlyDayType < TargetMeter
  private

  def target_amr_data(clone_kwh_x48, date, clone_date, clone_amr_data)
    day_type = @meter_collection.holidays.day_type(date)
    year_prior_average_profile_x48 = average_days_for_month_x48_xdaytype(clone_date, clone_amr_data)[day_type]
    target_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(year_prior_average_profile_x48, @target.target(date))
    OneDayAMRReading.new(mpan_mprn, date, 'TARG', nil, DateTime.now, target_kwh_x48)
  end

  def average_days_for_month_x48_xdaytype(date, amr_data)
    @average_profiles_for_month ||= {}
    first_of_month = DateTimeHelper.first_day_of_month(date)
    @average_profiles_for_month[first_of_month] ||= calculate_month_profile(amr_data, first_of_month)
  end

  def empty_profile
    {
      holiday:    [],
      weekend:    [],
      schoolday:  []
    }
  end

  def calculate_month_profile(amr_data, first_of_month)
    profiles = empty_profile
    last_of_month = DateTimeHelper.last_day_of_month(first_of_month)

    (first_of_month..last_of_month).each do |date|
      dt = @meter_collection.holidays.day_type(date)
      profiles[dt].push(amr_data.one_days_data_x48(date))
    end

    x = average_kwh_x48(profiles)
    x.each do |type, x48|
      if x48.any?{ |z| z.nan? }
        puts "Got here NaN #{first_of_month} #{type} TODO - change algorithm" 
        x[type] = AMRData.one_day_zero_kwh_x48
      end
    end
    x
  end

  def average_kwh_x48(profiles)
    profiles.transform_values do |kwhs_x48|
      total = AMRData.fast_add_multiple_x48_x_x48(kwhs_x48)
      AMRData.fast_multiply_x48_x_scalar(total, 1.0 / kwhs_x48.length)
    end
  end
end

# calculates average profiles from nearby days from previous year
# and then applies a scalar target reduction to them
# takes about 45ms per 365 days to calculate
# holiday averaging requirement less as don't want to have to go too far
# to a matching holiday which is too far seasonally away from the one
# we want to calculate an average profile for
class TargetMeterDailyDayType < TargetMeter
  NUM_SAME_DAYTYPE_REQUIRED = {
    holiday:     4,
    weekend:     6,
    schoolday:  10
  }
  private

  def target_amr_data(clone_kwh_x48, date, clone_date, clone_amr_data)
    days_average_profile_x48 = average_profile_for_day_x48(clone_date, clone_amr_data)
    target_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(days_average_profile_x48, @target.target(date))
    OneDayAMRReading.new(mpan_mprn, date, 'TARG', nil, DateTime.now, target_kwh_x48)
  end

  def scan_days_offset
    # work outwards from target day with these offsets
    # [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9, -9, 10, -10......-100]
    @scan_days ||= [0,(1..100).to_a.zip((-100..-1).to_a.reverse)].flatten
  end

  def average_profile_for_day_x48(date, amr_data)
    day_type = @meter_collection.holidays.day_type(date)
    profiles_to_average = []
    scan_days_offset.each do |days_offset|
      date_offset = date + days_offset
      if amr_data.date_exists?(date_offset) && @meter_collection.holidays.day_type(date_offset) == day_type
        profiles_to_average.push(amr_data.one_days_data_x48(date_offset))
      end
      break if profiles_to_average.length >= NUM_SAME_DAYTYPE_REQUIRED[day_type]
    end
    AMRData.fast_average_multiple_x48(profiles_to_average)
  end
end
