class TargetMeter < Dashboard::Meter
  class TargetStartDateBeforeFirstMeterDate < StandardError; end
  class UnexpectedPluralStorageHeaterFuel < StandardError; end
  include Logging
  attr_reader :target, :feedback, :target_dates, :non_scaled_target_meter, :synthetic_meter
  def initialize(meter_to_clone, do_calculations = true)
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

    @calculation_errors = {}

    if do_calculations
      @feedback = {}
      @original_meter = meter_to_clone
      @target = TargetAttributes.new(meter_to_clone)
      @target_dates = TargetDates.new(meter_to_clone, @target)

      bm = Benchmark.realtime {
        create_target_amr_data(meter_to_clone)
        calculate_carbon_emissions_for_meter
        calculate_costs_for_meter
      }
      @feedback[:calculation_time] = bm
      calc_text = "Calculated target meter #{mpan_mprn} #{fuel_type} in #{bm.round(3)} seconds"
      puts "Got here: #{calc_text}"
      logger.info calc_text
    end
  end

  def self.enough_amr_data_to_set_target?(meter)
    if meter.fuel_type == :gas
      true
    elsif meter.fuel_type == :electricity
      true
    elsif storage_heater_fuel_type?(meter.fuel_type) ||
      true
    else
      meter.amr_data.end_date > Date.today - 30 &&
      meter.amr_data.days > 365 + 30
    end
  end

  def self.storage_heater_fuel_type?(fuel_type)
    raise UnexpectedPluralStorageHeaterFuel, "Unexpected plural storage heater fuel for #{@original_meter.mpxn}" if fuel_type == :storage_heaters
    
    fuel_type == :storage_heater
  end

  def self.annual_kwh_estimate_required?(meter)
    !dates(meter).full_years_benchmark_data?
  end

  def self.recent_data?(meter)
    dates(meter).recent_data?
  end

  def self.enough_holidays?(meter)
    dates(meter).enough_holidays?
  end

  def target_degree_days(date)
    @target_degree_days ||= {}
    @target_degree_days[date] ||= @meter_collection.temperatures.degree_days(date)
  end

  def set_target_degree_days(degree_days)
    @target_degree_days ||= {}
    @target_degree_days.merge!(degree_days)
  end

  def all_degree_days
    @target_degree_days ||= {}
  end

  private_class_method def self.dates(meter)
    TargetDates.new(meter, TargetAttributes.new(meter))
  end

  def analytics_debug_info
    @feedback
  end

  def self.calculation_factory(type, meter_to_clone)
    case type
    when :month
      TargetMeterMonthlyDayType.new(meter_to_clone)
    when :day
      if meter_to_clone.fuel_type == :gas || storage_heater_fuel_type?(meter_to_clone.fuel_type)
        TargetMeterTemperatureCompensatedDailyDayType.new(meter_to_clone)
      else
        TargetMeterDailyDayType.new(meter_to_clone)
      end
    else
      raise EnergySparksUnexpectedStateException, "Unexpected target averaging type #{type}"
    end
  end

  private

  def create_target_amr_data(meter_to_clone)
    # Stage 1: if there is less than 1 year of existing amr data, synthesize up to 1 year
    adjusted_amr_data_info = if_less_than_one_year_historic_data_make_up_to_one_year_using_synthetic_calculated_data(meter_to_clone)
puts "Got here #{adjusted_amr_data_info[:amr_data].total}"
    # Stage 2: use one year or real and/or synthetic amr data to project a target for next year
    create_averaged_and_or_temperature_compensated_target_data(adjusted_amr_data_info, meter_to_clone)
  end

  def if_less_than_one_year_historic_data_make_up_to_one_year_using_synthetic_calculated_data(meter_to_clone)
    adjusted_amr_data_info = OneYearTargetingAndTrackingAmrData.new(meter_to_clone, target_dates).last_years_amr_data

    @feedback.merge!(adjusted_amr_data_info[:feedback])

    create_1_year_synthetic_historic_meter(adjusted_amr_data_info[:amr_data], meter_to_clone)

    adjusted_amr_data_info
  end

  def create_1_year_synthetic_historic_meter(amr_data, meter_to_clone)
    @synthetic_meter = create_non_scaled_meter(self)
    @synthetic_meter.amr_data = amr_data
  end

  def create_averaged_and_or_temperature_compensated_target_data(adjusted_amr_data_info, meter_to_clone)   
    @amr_data = AMRData.new(meter_to_clone.meter_type)
    @non_scaled_target_meter = create_non_scaled_meter(self)

    @target_dates.target_date_range.each do |target_date|
      synthetic_date = target_date - 364
      days_amr_data = target_one_day_amr_data(target_date: target_date, synthetic_date: synthetic_date, synthetic_amr_data: adjusted_amr_data_info[:amr_data])
      @amr_data.add(target_date, days_amr_data[:scaled])
      @non_scaled_target_meter.amr_data.add(target_date, days_amr_data[:non_scaled])
    end

    save_debug unless Object.const_defined?('Rails') || @calculation_errors.empty?

    @non_scaled_target_meter.set_target_degree_days(self.all_degree_days)
  end

  def create_non_scaled_meter(meter_to_clone)
    non_scaled_meter = self.class.new(meter_to_clone, false)
    non_scaled_meter.amr_data = AMRData.new(meter_to_clone.meter_type)
    non_scaled_meter
  end

  def target_one_day_amr_data(target_date:, synthetic_date:, synthetic_amr_data:)
    days_average_profile_x48 = profile_x48(target_date: target_date, synthetic_date: synthetic_date, synthetic_amr_data: synthetic_amr_data)
    target_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(days_average_profile_x48, @target.target(target_date))
    {
      scaled:     OneDayAMRReading.new(mpan_mprn, target_date, 'TARG', nil, DateTime.now, target_kwh_x48),
      non_scaled: OneDayAMRReading.new(mpan_mprn, target_date, 'TARG', nil, DateTime.now, days_average_profile_x48)
    }
  end

  # TODO(PH, 14Jan2021) ~~~ duplicate of code in aggregation mixin
  def calculate_carbon_emissions_for_meter
    if fuel_type == :electricity ||
       fuel_type == :aggregated_electricity ||
        TargetMeter.storage_heater_fuel_type?(fuel_type)
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

  def profile_x48(target_date:, synthetic_date:, synthetic_amr_data:)
    day_type = @meter_collection.holidays.day_type(target_date)
    average_days_for_month_x48_xdaytype(synthetic_date, synthetic_amr_data)[day_type]
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

   average_kwh_x48(profiles)
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

  def profile_x48(target_date:, synthetic_date:, synthetic_amr_data:)
    average_profile_for_day_x48(synthetic_date: synthetic_date, synthetic_amr_data: synthetic_amr_data, target_date: target_date)
  end

  def scan_days_offset(distance = 100)
    # work outwards from target day with these offsets
    # [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9, -9, 10, -10......-100]
    @scan_days_offset ||= [0, (1..distance).to_a.zip((-distance..-1).to_a.reverse)].flatten
  end

  def average_profile_for_day_x48(synthetic_date:, synthetic_amr_data:, target_date: nil)
    day_type = @meter_collection.holidays.day_type(synthetic_date)
    profiles_to_average = []
    scan_days_offset.each do |days_offset|
      date_offset = synthetic_date + days_offset
      if synthetic_amr_data.date_exists?(date_offset) && @meter_collection.holidays.day_type(date_offset) == day_type
        profiles_to_average.push(synthetic_amr_data.one_days_data_x48(date_offset))
      end
      break if profiles_to_average.length >= NUM_SAME_DAYTYPE_REQUIRED[day_type]
    end
    AMRData.fast_average_multiple_x48(profiles_to_average)
  end
  alias_method :average_profile_for_day_x48_super, :average_profile_for_day_x48
end
