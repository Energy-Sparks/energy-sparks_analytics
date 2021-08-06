require_relative './gas_estimation_base.rb'
# for targeting and tracking:
# - where there is less than 1 year of gas amr_data
# - and the gas modelling is working
# estimate a complete year's worth of gas data using regression model data
class ModelGasEstimation < GasEstimationBase
  HEATING_ON_DEGREE_DAYS = 0.0

  def complete_year_amr_data
    missing_days = calculate_missing_days

    scale = if @annual_kwh.nil?
              1.0
            else
              missing_days_scale(missing_days)
            end
        
    add_scaled_missing_days(missing_days, scale)
    
    one_year_amr_data
  end

  private

  def calculate_missing_days
    missing_days = {}

    (start_of_year_date..@amr_data.end_date).each do |date|
      next if one_year_amr_data.date_exists?(date)

      avg_temp = @meter.meter_collection.temperatures.average_temperature(date)

      dd = @meter.meter_collection.temperatures.degree_days(date)

      heating_on = dd > HEATING_ON_DEGREE_DAYS

      days_kwh =  if heating_on
                    heating_model.predicted_heating_kwh_future_date(date, avg_temp)
                  else
                    heating_model.predicted_non_heating_kwh_future_date(date, avg_temp)
                  end

      model_type = heating_on ? heating_model.heating_model_for_future_date(date) : heating_model.non_heating_model_for_future_date(date)

      profile = profiles_by_model_type_x48[model_type]

      missing_days[date] = { days_kwh: days_kwh, profile: profile }
    end
    missing_days
  end

  def missing_days_scale(missing_days)
    total_kwh_so_far = calculate_holey_amr_data_total_kwh(one_year_amr_data)

    total_missing_days = missing_days.values.map { |missing_day| missing_day[:days_kwh] }.sum # statsample bug avoidance

    remaining_kwh = @annual_kwh - total_kwh_so_far

    remaining_kwh / total_missing_days
  end

  def add_scaled_missing_days(missing_days, scale)
    missing_days.each do |date, missing_day|
      add_scaled_days_kwh(date, scale * missing_day[:days_kwh], missing_day[:profile])
    end
  end

  def profiles_by_model_type_x48
    @profiles_by_model_type_x48 ||= calculate_profiles_by_model_type_x48
  end

  def calculate_profiles_by_model_type_x48
    profiles_by_model_type = {}
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      next unless one_year_amr_data.date_exists?(date)

      model_type = heating_model.model_type?(date)

      profiles_by_model_type[model_type] ||= []

      profiles_by_model_type[model_type].push(@amr_data.days_kwh_x48(date))
    end

    average_profiles = profiles_by_model_type.transform_values do |n_x_48|
      total_all_days_x48 = AMRData.fast_add_multiple_x48_x_x48(n_x_48)
      AMRData.fast_multiply_x48_x_scalar(total_all_days_x48, 1.0 / total_all_days_x48.sum)
    end

    average_profiles
  end

  def average_profile_x48(dates)
    matching_days = date.map do |date|
      @amr_data.days_kwh_x48(date)
    end
    
    if matching_days.empty?
      AMDData.one_day_zero_kwh_x48
    else
      total_all_days_x48 = AMRData.fast_add_multiple_x48_x_x48(matching_days)
      AMRData.fast_multiply_x48_x_scalar(total_all_days_x48, 1.0 / matching_days.length)
    end
  end
end
