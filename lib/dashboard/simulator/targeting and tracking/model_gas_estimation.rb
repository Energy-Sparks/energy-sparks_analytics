require_relative './gas_estimation_base.rb'
# for targeting and tracking:
# - where there is less than 1 year of gas amr_data
# - and the gas modelling is not working
# estimate a complete year's worth of gas data using degree days
class ModelGasEstimation < GasEstimationBase
  HEATING_ON_DEGREE_DAYS = 0.0

  def complete_year_amr_data
    calculate_missing_days
    one_year_amr_data
  end

  private

  def calculate_missing_days
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

      add_scaled_days_kwh(date, days_kwh, profile)
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
