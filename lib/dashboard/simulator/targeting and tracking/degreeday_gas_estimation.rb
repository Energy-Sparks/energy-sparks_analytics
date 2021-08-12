require_relative './gas_estimation_base.rb'
# for targeting and tracking:
# - where there is less than 1 year of gas amr_data
# - and the gas modelling is not working
# estimate a complete year's worth of gas data using degree days
class DegreeDayGasEstimation < GasEstimationBase
  def complete_year_amr_data
    fill_in_missing_data_by_daytype(:holiday)
    fill_in_missing_data_by_daytype(:weekend)
    percent_real_data = fill_in_missing_schoolday_data

    {
      amr_data:             one_year_amr_data,
      percent_real_data:    percent_real_data,
      adjustments_applied:  'less than 1 years data, filling in missing using degree day adjustment (no modelling data available)'
    }
  end

  private

  def fill_in_missing_schoolday_data
    adjustment_count = 0
    total_kwh_so_far = calculate_holey_amr_data_total_kwh(one_year_amr_data)
    remaining_kwh = @annual_kwh - total_kwh_so_far
    degree_days_remaining = calculate_degree_days_remaining(one_year_amr_data)
    school_day_profile_x48 = average_profile_for_day_type_x48(:schoolday)
    school_day_profile_total_kwh = school_day_profile_x48.sum

    (start_of_year_date..@amr_data.end_date).each do |date|
      next if @holidays.day_type(date) != :schoolday ||  one_year_amr_data.date_exists?(date)

      degree_days = @meter.meter_collection.temperatures.degree_days(date)

      predicted_kwh = remaining_kwh * (degree_days / degree_days_remaining)

      scale = predicted_kwh / school_day_profile_total_kwh

      add_scaled_days_kwh(date, scale, school_day_profile_x48)

      adjustment_count += 1
    end

    (365 - adjustment_count) / 365.0
  end

  def fill_in_missing_data_by_daytype(daytype)
    avg_profile_x48 = average_profile_for_day_type_x48(daytype)

    (start_of_year_date..@amr_data.end_date).each do |date|
      next if @holidays.day_type(date) != daytype || one_year_amr_data.date_exists?(date)

      one_days_reading = OneDayAMRReading.new(@meter.mpan_mprn, date, 'TARG', nil, DateTime.now, avg_profile_x48)
      one_year_amr_data.add(date, one_days_reading)
    end

    def calculate_degree_days_remaining(one_year_amr_data)
      degree_days = 0.0
      (start_of_year_date..@amr_data.end_date).each do |date|
        unless one_year_amr_data.date_exists?(date)
          degree_days += @meter.meter_collection.temperatures.degree_days(date)
        end
      end
      degree_days
    end
  end
end