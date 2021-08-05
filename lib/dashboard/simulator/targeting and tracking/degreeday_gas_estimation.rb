require_relative './gas_estimation_base.rb'
# for targeting and tracking:
# - where there is less than 1 year of gas amr_data
# - and the gas modelling is not working
# estimate a complete year's worth of gas data using degree days
class DegreeDayGasEstimation < GasEstimationBase
  def complete_year_amr_data
    fill_in_missing_data_by_daytype(:holiday)
    fill_in_missing_data_by_daytype(:weekend)
    fill_in_missing_schoolday_data
    one_year_amr_data
  end

  private

  def start_of_year_date
    @amr_data.end_date - 364
  end

  def fill_in_missing_schoolday_data
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

      days_x48 = AMRData.fast_multiply_x48_x_scalar(school_day_profile_x48, scale)

      one_days_reading = OneDayAMRReading.new(@meter.mpan_mprn, date, 'TARG', nil, DateTime.now, days_x48)
      one_year_amr_data.add(date, one_days_reading)
    end
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

  def calculate_holey_amr_data_total_kwh(holey_data)
    total = 0.0
    (holey_data.start_date..holey_data.end_date).each do |date|
      total += holey_data.one_day_total(date) if holey_data.date_exists?(date)
    end
    total
  end
end
