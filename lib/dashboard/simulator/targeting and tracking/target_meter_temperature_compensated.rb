class TargetMeterTemperatureCompensatedDailyDayType < TargetMeterDailyDayType
  class UnableToFindMatchingProfile < StandardError; end
  DEGREEDAY_BASE_TEMPERATURE = 15.5
  RECOMMENDED_HEATING_ON_TEMPERATURE = 14.5
  WITHIN_TEMPERATURE_RANGE = 3.0

  def target_degreedays_average_in_date_range(d1, d2)
    d_days = 0.0
    (d1..d2).each do |date|
      d_days += target_degree_days(date)
    end
    d_days / (d2 - d1 + 1)
  end

  def save_debug
    unless @calculation_errors[:temperature_compensation_profile_matching].empty?
      save_debug_to_csv(@calculation_errors[:temperature_compensation_profile_matching])
    end
  end

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

  def average_profile_for_day_x48(target_date:, synthetic_amr_data:, synthetic_date:)
    compensation_temperature = target_temperature(target_date: target_date, synthetic_date: synthetic_date)

    profile = averaged_temperature_target_profile(synthetic_amr_data, synthetic_date, compensation_temperature)

    profile[:profile_x48]
  end

  def target_temperature(target_date:, synthetic_date:)
    @target_temperature ||= {}
    @target_temperature[target_date] = calculate_target_temperature(synthetic_date, target_date)

    @target_degree_days ||= {}
    @target_degree_days[target_date] ||= [0.0, DEGREEDAY_BASE_TEMPERATURE - @target_temperature[target_date]].max

    @target_temperature[target_date]
  end

  def target_degree_days(date)
    @target_degree_days[date]
  end

  def calculate_target_temperature(synthetic_date, target_date)
    past_target = target_date <= target_dates.original_meter_end_date

    if past_target
      temperatures.average_temperature(target_date)
    else
      target_temperature = temperatures.average_temperature_for_time_of_year(time_of_year: TimeOfYear.to_toy(synthetic_date), days_either_side: 4)
    end
  end

  # =========================================================================================
  # general functions both future and past target date

  def averaged_temperature_target_profile(synthetic_amr_data, synthetic_date, target_temperature)   
    heating_on = should_heating_be_on?(synthetic_date, target_temperature)

    profiles_to_average = find_matching_profiles_with_retries(synthetic_date, target_temperature, heating_on, synthetic_amr_data)
    
    if profiles_to_average.empty?
      error = "Unable to find matching profile for #{synthetic_date.strftime("%a %d %b %Y")} T = #{target_temperature.round(1)} Heating should be on: #{heating_on} on/at #{holidays.day_type(synthetic_date)} - csv search path debug available in the analytics"
      raise UnableToFindMatchingProfile, error if Object.const_defined?('Rails')
      
      puts error
    end

    model = local_heating_model(synthetic_amr_data)

    predicated_kwh = model.predicted_kwh_for_future_date(heating_on, synthetic_date, target_temperature)

    {
      profile_x48:  normalised_profile_to_predicted_kwh_x48(profiles_to_average.values, predicated_kwh),
      temperature:  target_temperature,
      heating_on:   heating_on
    }
  end

  def find_matching_profiles_with_retries(synthetic_date, target_temperature, heating_on, amr_data)
    if holidays.day_type(synthetic_date) == :schoolday
      profiles = find_matching_profiles(synthetic_date, target_temperature, heating_on, amr_data, 14)
      return profiles unless profiles.empty?

      find_matching_profiles(synthetic_date, target_temperature, heating_on, amr_data, 14, true)
    else
      profiles = find_matching_profiles(synthetic_date, target_temperature, heating_on, amr_data)
      return profiles unless profiles.empty?

      return profiles if target_temperature > RECOMMENDED_HEATING_ON_TEMPERATURE || heating_on

      # if heating should be off, but is actually on, then try setting a target with it on
      # as long as its not too warm

      find_matching_profiles(synthetic_date, target_temperature, true, amr_data)
    end
  end

  def find_matching_profiles(synthetic_date, target_temperature, heating_on, amr_data, scan_distance = 100, ignore_weekday = false)
    profiles_to_average = {}

    scan_failures = []

    day_type = holidays.day_type(synthetic_date)

    model = local_heating_model(amr_data)

    scan_days_offset(scan_distance).each do |days_offset|
      date_offset = synthetic_date + days_offset
      synthetic_temperature = temperatures.average_temperature(date_offset)

      if amr_data.date_exists?(date_offset) &&
         matching_day?(date_offset, synthetic_date, model.thermally_massive?, heating_on, ignore_weekday) == true &&
         temperature_within_range?(synthetic_temperature, target_temperature, heating_on) &&
         model.heating_on?(date_offset) == heating_on
        profiles_to_average[synthetic_temperature] = amr_data.one_days_data_x48(date_offset)
      else
        failure = {
          scan_date:              date_offset,
          amr_data:               amr_data.date_exists?(date_offset),
          matching_day:           matching_day?(date_offset, synthetic_date, model.thermally_massive?, heating_on, ignore_weekday),
          temperature_in_range:   temperature_within_range?(synthetic_temperature, target_temperature, heating_on),
          heating_on_match:       model.heating_on?(date_offset) == heating_on
        }
        scan_failures.push(failure)
      end

      break if profiles_to_average.length >= num_same_day_type_required(amr_data)[day_type]
    end

    if profiles_to_average.empty?
      @calculation_errors[:temperature_compensation_profile_matching] ||= []
      debug = {
        day_type:           day_type,
        synthetic_date:     synthetic_date,
        target_temperature: target_temperature,
        heating_on:         heating_on,
        thermally_massive:  model.thermally_massive?,
        ignore_weekday:     ignore_weekday,
        scan_distance:      scan_distance,
        scan_failures:      scan_failures
      }

      @calculation_errors[:temperature_compensation_profile_matching].push(debug)
    end

    profiles_to_average
  end

  def save_debug_to_csv(calc_errors)
    filename = "./Results/targeting and tracking profile scanning failures #{object_id}.csv"
 
    puts "Saving results to #{filename}"
    
    col_names = [
      calc_errors.first.select { |k, _v| k != :scan_failures }.keys,
      calc_errors.first[:scan_failures].first.keys
    ].flatten

    CSV.open(filename, 'w') do |csv|
      csv << col_names
      calc_errors.each do |one_day_calc_error|
        non_scan_failure_data = one_day_calc_error.select { |k, _v| k != :scan_failures }.values

        one_day_calc_error[:scan_failures].each do |scan_failure_data|
          csv << [non_scan_failure_data, scan_failure_data.values].flatten
        end
      end

      Thread.current.backtrace.each do |line|
        csv << ['Stacktrace', line]
      end
    end
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

  def temperature_within_range?(temperature, range_temperature, heating_on)
    within_range = heating_on ? WITHIN_TEMPERATURE_RANGE : 2.0 * WITHIN_TEMPERATURE_RANGE
    temperature.between?(range_temperature - within_range, range_temperature + within_range)
  end

  def matching_day?(synthetic_date, target_date, thermally_massive, heating_on, ignore_weekday)
    match_failure_type?(synthetic_date, target_date, thermally_massive, heating_on, ignore_weekday)
  end

  def match_failure_type?(synthetic_date, target_date, thermally_massive, heating_on, ignore_weekday)
    synthetic_day_type = holidays.day_type(synthetic_date)

    return :day_type unless synthetic_day_type == holidays.day_type(target_date)

    return true if %i[holiday weekend].include?(synthetic_day_type)

    return true if !thermally_massive || !heating_on || ignore_weekday

    synthetic_date.wday == target_date.wday ? true : :weekday
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
    debug.merge!(degree_day_debug)
    @feedback.merge!(debug)
    model
  end

  def degree_day_debug
    annual_degree_days = {}
    start_date = temperatures.end_date - 365

    while start_date >=  temperatures.start_date
      end_date = start_date + 365
      dr = "Annual degree days: #{start_date.strftime('%b %Y')}/#{end_date.year}"
      dd = temperatures.degree_days_in_date_range(start_date, end_date, DEGREEDAY_BASE_TEMPERATURE)
      annual_degree_days[dr] = dd
      start_date -= 365
    end

    return {} if annual_degree_days.empty?

    average = annual_degree_days.values.sum / annual_degree_days.length

    annual_degree_days.transform_values{ |dd| "#{dd.round(0)} dd: #{(100.0 * ((dd / average) - 1.0)).round(1)}%"}
  end
end
