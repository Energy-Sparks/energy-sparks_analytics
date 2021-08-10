require 'require_all'
# creates a 'target' school from an existing school
# the initial implementation is the school with the
# and data shifted 1 year and then scaled by the target factor
# with an attempt to correct for holidays, but set on a per month basis or a nearby day basis
class TargetSchool < MeterCollection
  include Logging
  def initialize(school, calculation_type)
    super(school.school,
          holidays:                 school.holidays,
          temperatures:             school.temperatures,
          solar_irradiation:        school.solar_irradiation,
          solar_pv:                 school.solar_pv,
          grid_carbon_intensity:    school.grid_carbon_intensity,
          pseudo_meter_attributes:  school.pseudo_meter_attributes_private)

    @original_school = school

    @aggregated_heat_meters         = set_target(school.aggregated_heat_meters,         calculation_type)
    @aggregated_electricity_meters  = set_target(school.aggregated_electricity_meters,  calculation_type)
    @storage_heater_meter           = set_target(school.storage_heater_meter,           calculation_type)

    @name += ': target'
  end

  private

  def set_target(meter, calculation_type)
    set_target?(meter) ? TargetMeter.calculation_factory(calculation_type, meter) : nil
  end

  def set_target?(meter)
=begin
    puts "Got here: setting meter #{meter.fuel_type} = 1: #{meter.nil?}"
    puts "2: #{meter.target_set? }"
    puts "3: #{meter.enough_amr_data_to_set_target? }"
=end
    !meter.nil? && meter.target_set? && meter.enough_amr_data_to_set_target? 
  end
end

class TargetAttributes
  attr_reader :attributes
  def initialize(meter)
    @attributes = nil
    if meter.target_set?
      @attributes = meter.target_attributes.sort { |a, b| a[:start_date] <=> b[:start_date] } 
    end
  end

  def table
    @attributes.map { |t| [t[:start_date], t[:target]] }
  end

  def target_date_ranges
    @target_date_ranges ||= convert_target_date_ranges
  end

  def average_target(start_date, end_date)
    weighted_values = target_date_ranges.map do |target_range, value|
      [
        overlap_days(start_date, end_date, target_range.first, target_range.last) * 1.0,
        value
      ]
    end
    sumproduct = weighted_values.map{ |(a,b)| a * b }.sum
    sumproduct / weighted_values.transpose[0].sum
  end

  def overlap_days(sd1, ed1, sd2, ed2)
    [[ed1, ed2].min - [sd1, sd2].max + 1, 0].max
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
      h[attributes[interim_index][:start_date]..attributes[interim_index+1][:start_date]] = attributes[interim_index][:target]
    end
    h[attributes[last_index][:start_date]..Date.new(2050, 1, 1)] = attributes[last_index][:target]
    h
  end
end

class TargetMeter < Dashboard::Meter
  include Logging
  attr_reader :target
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
      calculate_carbon_emissions_for_meter
      calculate_costs_for_meter
    }
    calc_text = "Calculated target meter #{mpan_mprn} in #{bm.round(3)} seconds"
    logger.info calc_text
  end

  def target_start_date(end_date)
    [end_date - 365, target.first_target_date, @original_meter.amr_data.start_date].max
  end

  def self.enough_amr_data_to_set_target?(meter)
    meter.amr_data.end_date > Date.today - 30 &&
    meter.amr_data.days > 365 + 30
  end

  def target_start_date_deprecated(date)
    academic_year = @meter_collection.holidays.calculate_academic_year_tolerant_of_missing_data(date)
    start_of_academic_year = Date.new(academic_year.start_date.year, academic_year.start_date.month, 1)
    target_start_date = target.first_target_date
    [start_of_academic_year, target_start_date].max
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
    end_date   = meter_to_clone.amr_data.end_date + 363 + 30 # + 30 allow a margin

    adjusted_amr_data_info = OneYearTargetingAndTrackingAmrData.new(meter_to_clone).last_years_amr_data

    target_amr_data = AMRData.new(meter_to_clone.meter_type)

    (start_date..end_date).each do |date|
      clone_date = date - 364
      target_kwh_x48 = target_one_day_amr_data(date, clone_date, adjusted_amr_data_info[:amr_data])
      target_amr_data.add(date, target_kwh_x48)
    end

    target_amr_data
  end

  # TODO(PH, 14Jan2021) ~~~ duplicate of code in aggregation mixin
  def calculate_carbon_emissions_for_meter
    if fuel_type == :electricity || fuel_type == :aggregated_electricity # TODO(PH, 6Apr19) remove : aggregated_electricity once analytics meter meta data loading changed
      @amr_data.set_carbon_emissions(id, nil, @meter_collection.grid_carbon_intensity)
    else
      @amr_data.set_carbon_emissions(id, EnergyEquivalences::UK_GAS_CO2_KG_KWH, nil)
    end
  end

  def calculate_costs_for_meter
    logger.info "Creating economic & accounting costs for target #{mpan_mprn} fuel #{fuel_type} from #{amr_data.start_date} to #{amr_data.end_date}"
    @amr_data.set_economic_tariff(self)
    @amr_data.set_accounting_tariff(self)
  end
end

# calculates average profiles per month from previous year
# and then applies a scalar target reduction to them
# takes about 24ms per 365 days to calculate
class TargetMeterMonthlyDayType < TargetMeter
  include Logging
  private

  def target_one_day_amr_data(date, clone_date, clone_amr_data)
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
        logger.info "Got here NaN #{first_of_month} #{type} TODO(PH, 14Jan2021) - change algorithm" 
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

  def target_one_day_amr_data(date, clone_date, clone_amr_data)
    days_average_profile_x48 = average_profile_for_day_x48(clone_date, clone_amr_data)
    target_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(days_average_profile_x48, @target.target(date))
    OneDayAMRReading.new(mpan_mprn, date, 'TARG', nil, DateTime.now, target_kwh_x48)
  end

  def scan_days_offset
    # work outwards from target day with these offsets
    # [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9, -9, 10, -10......-100]
    @scan_days_offset ||= [0, (1..100).to_a.zip((-100..-1).to_a.reverse)].flatten
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
