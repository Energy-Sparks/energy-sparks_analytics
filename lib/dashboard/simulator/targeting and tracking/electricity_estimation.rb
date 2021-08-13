class ElectricityEstimation < TargetingAndTrackingFittingBase
  def initialize(meter, target_dates)
    super(meter.amr_data, meter.meter_collection.holidays)
    @meter = meter
    @target_dates = target_dates
  end

  def complete_year_amr_data
    original_amr_kwh = @amr_data.total
    amr_with_lockdown_dates_removed_kwh = calculate_holey_amr_data_total_kwh(one_year_amr_data)

    weekly_normalised_profile = fit_to_log_norm_profile_by_week

    fill_in_missing_data_by_daytype(:holiday, @target_dates.synthetic_benchmark_date_range)
    fill_in_missing_data_by_daytype(:weekend, @target_dates.synthetic_benchmark_date_range)

    amr_kwh_after_holidays_and_weekend_created = calculate_holey_amr_data_total_kwh(one_year_amr_data)

    feedback1 = {
      sd_fit:                           fit_to_log_norm_profile_by_week[:sd],
      original_kwh:                     original_amr_kwh,
      kwh_with_lockdown_data_removed:   amr_with_lockdown_dates_removed_kwh,
      kwh_after_weekend_holidays_added: amr_kwh_after_holidays_and_weekend_created
    }

    feedback2 = fill_in_missing_schoolday_data

    feedback = feedback1.merge(feedback2)

    {
      amr_data: one_year_amr_data,
      feedback: feedback
    }
  end

  private

  def fit_to_log_norm_profile_by_week
    @fit_to_log_norm_profile_by_week ||= calculate_fit_to_log_norm_profile_by_week
  end

  def calculate_fit_to_log_norm_profile_by_week
    fitter = ElectricityAnnualProfileFitter.new(@meter.amr_data, @meter.meter_collection.holidays, @target_dates.benchmark_start_date, @target_dates.benchmark_end_date)
    fitter.fit(exclude_date_ranges: lockdown_date_ranges)
  end

  def lockdown_date_ranges
    adj = SeasonalMirroringCovidAdjustment.new(@meter, @meter.meter_collection.holidays)
    adj.lockdown_date_ranges
  end

  def one_year_amr_data
    @one_year_amr_data ||= create_amr_data_minus_lockdown_dates
  end

  def create_amr_data_minus_lockdown_dates
    amr_data = AMRData.copy_amr_data(@amr_data, @target_dates.benchmark_start_date, @target_dates.benchmark_end_date)
    lockdown_date_ranges.each do |date_range|
      date_range.each do |date|
        amr_data.delete(date)
      end
    end
    amr_data
  end

  def fill_in_missing_schoolday_data
    adjustment_count = 0
    total_kwh_so_far = calculate_holey_amr_data_total_kwh(one_year_amr_data)
    remaining_kwh = @meter.annual_kwh_estimate - total_kwh_so_far
    total_normalised_missing = missing_days_normalised_total

    school_day_profile_x48 = average_profile_for_day_type_x48(:schoolday)
    school_day_profile_total_kwh = school_day_profile_x48.sum

    @target_dates.synthetic_benchmark_date_range.each do |date|
      next if @holidays.day_type(date) != :schoolday || one_year_amr_data.date_exists?(date)

      week_of_year = ElectricityAnnualProfileFitter.week_of_year(date)
      week_weight  = fit_to_log_norm_profile_by_week[:profile][week_of_year]

      days_estimated_kwh = (week_weight / total_normalised_missing) * remaining_kwh

      scale = days_estimated_kwh / school_day_profile_total_kwh

      add_scaled_days_kwh(date, scale, school_day_profile_x48)

      adjustment_count += 1
    end

    final_post_calc_kwh = calculate_holey_amr_data_total_kwh(one_year_amr_data)

    {
      percent_real_data:      (365 - adjustment_count) / 365.0,
      corrected_school_days:  adjustment_count,
      kwh_prior_to_fit:       total_kwh_so_far,
      annual_estimate_kwh:    @meter.annual_kwh_estimate,
      remaining_kwh:          remaining_kwh,
      final_post_calc_kwh:    final_post_calc_kwh,
      rule:                   self.class.name
    }
  end

  def missing_days_normalised_total
    @missing_days_normalised_total ||= calculate_missing_days_normalised_total
  end

  def calculate_missing_days_normalised_total
    total = 0.0
    @target_dates.synthetic_benchmark_date_range.each do |date|
      next if @holidays.day_type(date) != :schoolday || one_year_amr_data.date_exists?(date)
      week_of_year = ElectricityAnnualProfileFitter.week_of_year(date)
      total += fit_to_log_norm_profile_by_week[:profile][week_of_year]
    end
    total
  end
end
