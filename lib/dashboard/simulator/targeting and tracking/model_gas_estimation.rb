require_relative './gas_estimation_base.rb'
# for targeting and tracking:
# - where there is less than 1 year of gas amr_data
# - and the gas modelling is working
# estimate a complete year's worth of gas data using regression model data
class ModelGasEstimation < GasEstimationBase
  HEATING_ON_DEGREE_DAYS = 0.0

  def complete_year_amr_data
    missing_days = calculate_missing_days

    puts "Got here: missing days"
    ap missing_days.transform_values{ |oneday| oneday[:days_kwh] }

    scale = if @annual_kwh.nil?
              1.0
            else
              missing_days_scale(missing_days)
            end

    scale_description = scale == 1.0 ? ' - no annual kwh estimate to scale' : ''

    add_scaled_missing_days(missing_days, scale)

    model_description = heating_model.models.transform_values(&:to_s)

    puts "Got here: one year data"
    ap one_year_amr_data.transform_values{ |oneday| oneday.one_day_kwh }

    results = {
      amr_data:             one_year_amr_data,
      feedback: {
        percent_real_data:            (365 - missing_days.length)/ 365.0,
        adjustments_applied:          "less than 1 years data, filling in missing using regression models #{scale_description}",
        rule:                         self.class.name,
        start_of_year:                start_of_year_date,
        end_of_year:                  @amr_data.end_date,
        unadjusted_missing_days_kwh:  @total_missing_days,
        total_real_kwh:               @total_kwh_so_far,
        annual_estimated_kwh:         @annual_kwh,
        percent_synthetic_kwh:        (@annual_kwh - @total_kwh_so_far) / @annual_kwh
      }
    }

    results[:feedback].merge!(model_description)

    results
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
    @total_kwh_so_far = calculate_holey_amr_data_total_kwh(one_year_amr_data)

    @total_missing_days = missing_days.values.map { |missing_day| missing_day[:days_kwh] }.sum # statsample bug avoidance

    remaining_kwh = @annual_kwh - @total_kwh_so_far

    remaining_kwh / @total_missing_days
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
end
