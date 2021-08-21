class TargetMeter < Dashboard::Meter
  class TargetStartDateBeforeFirstMeterDate < StandardError; end
  class UnexpectedPluralStorageHeaterFuel < StandardError; end
  include Logging
  attr_reader :target, :feedback, :target_dates
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
    @feedback = {}
    @original_meter = meter_to_clone
    @target = TargetAttributes.new(meter_to_clone)
    @target_dates = TargetDates.new(meter_to_clone, @target)

    bm = Benchmark.realtime {
      @amr_data = create_target_amr_data(meter_to_clone)
      calculate_carbon_emissions_for_meter
      calculate_costs_for_meter
    }
    @feedback[:calculation_time] = bm
    calc_text = "Calculated target meter #{mpan_mprn} in #{bm.round(3)} seconds"
    puts "Got here: #{calc_text}"
    logger.info calc_text
  end

  def self.enough_amr_data_to_set_target?(meter)
    if meter.fuel_type == :gas
      true
    elsif meter.fuel_type == :electricity
      true
    elsif storage_heater_fuel_type?(fuel_type) ||
      true
    else
      meter.amr_data.end_date > Date.today - 30 &&
      meter.amr_data.days > 365 + 30
    end
  end

  def self.storage_heater_fuel_type?(fuel_type)
    raise UnexpectedPluralStorageHeaterFuel, "Unexepected plural storage heater fuel for #{@original_meter.mpxn}" if fuel_type == :storage_heaters
    
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
    adjusted_amr_data_info = OneYearTargetingAndTrackingAmrData.new(meter_to_clone, target_dates).last_years_amr_data

    @feedback.merge!(adjusted_amr_data_info[:feedback])

    target_amr_data = AMRData.new(meter_to_clone.meter_type)

    @target_dates.target_date_range.each do |date|
      clone_date = date - 364
      target_kwh_x48 = target_one_day_amr_data(date, clone_date, adjusted_amr_data_info[:amr_data])
      target_amr_data.add(date, target_kwh_x48)
    end

    target_amr_data
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

  def target_one_day_amr_data(date, clone_date, clone_amr_data)
    days_average_profile_x48 = average_profile_for_day_x48(clone_date, clone_amr_data, date)
    target_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(days_average_profile_x48, @target.target(date))
    OneDayAMRReading.new(mpan_mprn, date, 'TARG', nil, DateTime.now, target_kwh_x48)
  end

  def scan_days_offset
    # work outwards from target day with these offsets
    # [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9, -9, 10, -10......-100]
    @scan_days_offset ||= [0, (1..100).to_a.zip((-100..-1).to_a.reverse)].flatten
  end

  def average_profile_for_day_x48(date, amr_data, _current_meter_date)
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
  alias_method :average_profile_for_day_x48_super, :average_profile_for_day_x48
end

class TargetMeterTemperatureCompensatedDailyDayType < TargetMeterDailyDayType
  DEGREEDAY_BASE_TEMPERATURE = 15.5
  RECOMMENDED_HEATING_ON_TEMPERATURE = 14.5
  WITHIN_TEMPERATURE_RANGE = 3.0

  private
  
  def num_same_day_type_required(amr_data)
    # thermally massive model day of week dependent so
    # unlikely to be able to scan that far to find dates
    # within temperature range, so school day profiles
    # will be less smoothed
    {
      holiday:     4,
      weekend:     6,
      schoolday:   local_heating_model(amr_data).thermally_massive? ? 4 : 10
    }
  end

  def temperatures
    meter_collection.temperatures
  end

  def holidays
    meter_collection.holidays
  end

  def average_profile_for_day_x48(target_date, amr_data, benchmark_date)
    temperature_compensate_past_target = target_dates.original_meter_end_date >= benchmark_date
    
    profile = if temperature_compensate_past_target
      averaged_temperature_target_profile_target_temperature(benchmark_date, amr_data, target_date)
    else
      averaged_temperature_target_profile_average_temperature(benchmark_date, amr_data, target_date)
    end

    profile[:profile_x48]
  end

  # =========================================================================================
  # calculate future target amr data past today using an historically averaged temperature
  #
  # the targeting system uses either real or synthetic data from one year previously to set
  # a target e.g. a target for March 2021 would be derived from historic data from March 2020
  # for this to be realistic the March 2020 data needs to be temperature compensated to average
  # temperatures for March, and not directly use March 2020 heating consumption as it might have
  # been a particularly hot or cold March and thus might be setting an unrealistic target
  def averaged_temperature_target_profile_average_temperature(benchmark_date, amr_data, target_date)
    target_temperature = temperatures.average_temperature_for_time_of_year(time_of_year: TimeOfYear.to_toy(benchmark_date), days_either_side: 2)

    averaged_temperature_target_profile(amr_data, target_date, target_temperature)
  end

    # =========================================================================================
  # restate target for date which is now past, as the date needs temperature compensating
  # - so if the target date was colder than expected then revise the target up,
  #   or down if warmer than expected
  #
  def averaged_temperature_target_profile_target_temperature(benchmark_date, amr_data, target_date)
    target_temperature = temperatures.average_temperature(target_date)

    averaged_temperature_target_profile(amr_data, target_date, target_temperature)
  end

  # =========================================================================================
  # general functions both future and past target date

  def averaged_temperature_target_profile(amr_data, target_date, target_temperature)
    heating_on = should_heating_be_on?(target_temperature)

    profiles_to_average = find_matching_profiles(target_date, target_temperature, heating_on, amr_data)

    model = local_heating_model(amr_data)

    predicated_kwh = model.predicted_kwh_for_future_date(heating_on, target_date, target_temperature)
    
    {
      profile_x48:  normalised_profile_to_predicted_kwh_x48(profiles_to_average.values, predicated_kwh),
      temperature:  target_temperature,
      heating_on:   heating_on
    }
  end

  def find_matching_profiles(target_date, target_temperature, heating_on, amr_data)
    profiles_to_average = {}

    day_type = holidays.day_type(target_date)

    model = local_heating_model(amr_data)
    
    scan_days_offset.each do |days_offset|
      date_offset = target_date + days_offset
      benchmark_temperature = temperatures.average_temperature(date_offset)

      if amr_data.date_exists?(date_offset) &&
         matching_day?(date_offset, target_date, model.thermally_massive?) &&
         temperature_within_range?(benchmark_temperature, target_temperature) &&
         model.heating_on?(date_offset) == heating_on
        profiles_to_average[benchmark_temperature] = amr_data.one_days_data_x48(date_offset)
      end
      break if profiles_to_average.length >= num_same_day_type_required(amr_data)[day_type]
    end

    profiles_to_average
  end

  # rather than following when the school turned its heating on or off in the previous year
  # artificially determine whether the heating should have been on or off
  # - determine from statistics calculating the degreeday balance point temperature
  # - could be fitted to the school, but for the moment for simplicity and to set the schools'
  #   a challenge set to temperature to a fixed amount
  def should_heating_be_on?(target_temperature)
    target_temperature < RECOMMENDED_HEATING_ON_TEMPERATURE
  end

  # don't temperature weight for the moment as for the majority, thermally
  # massive schools there are probably too few samples, and they may be biased
  # below or above the target temperature, in the shoulder seasons.
  #
  # - temperature compensated profiles are also trickey, as instead of increased
  #   kWh consumption per half hour, as assumed here (although within similar
  #   temperature range), more likely delivered by longer heating day i.e. wider profile
  #
  # - normalisation and temperature compensation in 1 function for performance as N (4-10) x 48 multiplications
  #
  def normalised_profile_to_predicted_kwh_x48(profiles_x48, predicated_kwh)
    normalised_profiles = profiles_x48.map do |profile_x48|
      days_kwh = profile_x48.sum
      if days_kwh == 0.0
        Array.new(48, 0.0)
      else
        profile_x48.map do |half_hour_kwh|
          half_hour_kwh / days_kwh
        end
      end
    end

    sum_normalised_profiles_x48 = AMRData.fast_add_multiple_x48_x_x48(normalised_profiles)

    AMRData.fast_multiply_x48_x_scalar(sum_normalised_profiles_x48, predicated_kwh / normalised_profiles.length) 
  end

  def temperature_within_range?(temperature, range_temperature)
    temperature.between?(range_temperature - WITHIN_TEMPERATURE_RANGE, range_temperature + WITHIN_TEMPERATURE_RANGE)
  end

  def matching_day?(benchmark_date, target_date, thermally_massive)
    benchmark_day_type = holidays.day_type(benchmark_date)

    return false unless benchmark_day_type == holidays.day_type(target_date)

    return true if %i[holiday weekend].include?(benchmark_day_type)

    return true unless thermally_massive
    
    benchmark_date.wday == target_date.wday
  end

  # =========================================================================================
  # local heating model management
  #
  # for the moment define the modelling period as that of the most recent
  # 1 year period, of the original meter, plus synthetic data if the original
  # meter has less data, rather than just using the modelling before the target
  # date - this runs the risk the model significantly evolves over time adjusting the
  # original target but is balanced against the model improving with more real data and
  # less synthetic data as time progresses
  # - there is a general expectation the model should always run as the prior synthetic
  # - meter generation process of up to 1 year should ensure there is enough data with
  #   reasonable thermostatic characteristics
  def heating_model_period(amr_data)
    end_date = amr_data.end_date
    start_date = [end_date - 364, amr_data.start_date].max
    period = SchoolDatePeriod.new(:target_meter, '1 yr benchmark', start_date, end_date)
  end
  
  def local_heating_model(amr_data)
    @local_heating_model ||= calc_local_heating_model(amr_data)
  end

  def calc_local_heating_model(amr_data)
    # self(Meter).amr_data not set yet so create temporary meter for model
    meter_for_model = Dashboard::Meter.clone_meter_without_amr_data(self)
    meter_for_model.amr_data = amr_data

    model = meter_for_model.heating_model(heating_model_period(amr_data))
    debug = model.models.transform_values(&:to_s)
    debug.transform_keys!{ |key| :"temperature_compensation#{key}" }
    debug[:temperature_compensation_model] = model.class.name
    debug[:temperature_compensation_thermally_massive] = model.thermally_massive?
    @feedback.merge!(debug)
    model
  end
end
