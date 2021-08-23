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
    compensation_temperature = target_temperature(benchmark_date, target_date)

    profile = averaged_temperature_target_profile(amr_data, target_date, compensation_temperature)

    profile[:profile_x48]
  end

  def target_temperature(benchmark_date, target_date)
    @target_temperature ||= {}
    @target_temperature[target_date] = calculate_target_temperature(benchmark_date, target_date)
  end

  # assumes @target_temperature already calculated
  def target_degree_days(date)
    [0.0, DEGREEDAY_BASE_TEMPERATURE - @target_temperature[date]].max
  end

  def calculate_target_temperature(benchmark_date, target_date)
    temperature_compensate_past_target = target_dates.original_meter_end_date >= benchmark_date

    if temperature_compensate_past_target
      temperatures.average_temperature(target_date)
    else
      target_temperature = temperatures.average_temperature_for_time_of_year(time_of_year: TimeOfYear.to_toy(benchmark_date), days_either_side: 2)
    end
  end

  # =========================================================================================
  # general functions both future and past target date

  def averaged_temperature_target_profile(amr_data, target_date, target_temperature)
    heating_on = should_heating_be_on?(target_date, target_temperature)

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
  # - holidays and weekends potentially problematic if a school switches
  #   heating on/off in these periods from 1 year to the next TODO(PH, 23Aug2021) - further thought required
  def should_heating_be_on?(target_date, target_temperature)
    holidays.day_type(target_date) == :schoolday &&
    target_temperature < RECOMMENDED_HEATING_ON_TEMPERATURE
  end

  # don't temperature weight for the moment as for the majority, thermally
  # massive schools there are probably too few samples, and they may be biased
  # below or above the target temperature, in the shoulder seasons.
  #
  # - temperature compensated profiles are also tricky, as instead of increased
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
    debug.transform_keys!{ |key| :"temperature_compensation_#{key}" }
    debug[:temperature_compensation_model] = model.class.name
    debug[:temperature_compensation_thermally_massive] = model.thermally_massive?
    @feedback.merge!(debug)
    model
  end
end
