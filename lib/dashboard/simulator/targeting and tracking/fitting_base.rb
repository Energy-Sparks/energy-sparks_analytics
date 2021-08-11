class TargetingAndTrackingFittingBase
  def initialize(amr_data, holidays)
    @amr_data = amr_data
    @holidays = holidays
  end

  private

  def average_kwh_for_daytype(start_date, end_date, daytype = :schoolday)
    total = 0.0
    count = 0
    (start_date..end_date).each do |date|
      next if @holidays.day_type(date) != daytype
      if date.between?(@amr_data.start_date, @amr_data.end_date)
        total += @amr_data.one_day_kwh(date)
        count += 1
      end
    end
    total / count
  end

  def average_profile_for_day_type_x48(daytype)
    matching_days = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if @holidays.day_type(date) == daytype && @amr_data.date_exists?(date)
        matching_days.push(@amr_data.days_kwh_x48(date))
      end     
    end
    
    if matching_days.empty?
      AMDData.one_day_zero_kwh_x48
    else
      total_all_days_x48 = AMRData.fast_add_multiple_x48_x_x48(matching_days)
      AMRData.fast_multiply_x48_x_scalar(total_all_days_x48, 1.0 / matching_days.length)
    end
  end
end
