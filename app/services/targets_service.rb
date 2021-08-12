class TargetsService
  def initialize(aggregate_school, fuel_type)
    @aggregate_school = aggregate_school
    @fuel_type = fuel_type
  end

  def progress
    TargetsProgress.new(
      fuel_type: @fuel_type,
      months: data_headers,
      monthly_targets_kwh: data_series(:full_targets_kwh),
      monthly_usage_kwh: data_series(:current_year_kwhs),
      monthly_performance: data_series(:monthly_performance),
      cumulative_targets_kwh: data_series(:full_cumulative_targets_kwhs),
      cumulative_usage_kwh: data_series(:full_cumulative_current_year_kwhs),
      cumulative_performance: data_series(:cumulative_performance),
      monthly_performance_versus_synthetic_last_year: data_series(:monthly_performance_versus_last_year),
      cumulative_performance_versus_synthetic_last_year: data_series(:cumulative_performance_versus_last_year),

      partial_months: data_series(:partial_months)
    )
  end

  #Called by application to determine if we have enough data for a school to
  #set and calculate a target. Should cover all necessary data
  #
  #We require at least a years worth of calendar data, as well as ~1 year of AMR data OR an estimate of their annual consumption
  def enough_data_to_set_target?
    return enough_calendar_data_to_calculate_target? && (enough_amr_data_to_set_target? || aggregate_meter.estimated_period_consumption_set? )
  end

  #return true if there is sufficient historical data
  def enough_amr_data_to_calculate_target?
    return false unless aggregate_meter.present?
    aggregate_meter.enough_amr_data_to_set_target?
  end

  #return true if there is enough calendar data to calculate the target
  def enough_calendar_data_to_calculate_target?
    last_holiday = @aggregate_school.holidays.last
    return false unless last_holiday.present? && last_holiday.academic_year.present?
    last_holiday.academic_year.last >= Time.now.year + 1
  end

  def relevance
    aggregate_meter.nil? ? :never_relevant : :relevant
  end

  def annual_kwh_estimate_required?
    TargetMeter.annual_kwh_estimate_required?(aggregate_meter)
  end

  # for backwards compatibility
  # schools without meter attributes set
  # may not be needed by front end
  def target_set?
    aggregate_meter.target_set?
  end

  def culmulative_progress_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_to_date_cumulative_line
    when :gas
      :targeting_and_tracking_weekly_gas_to_date_cumulative_line
    when :storage_heater
      :targeting_and_tracking_weekly_storage_heater_to_date_cumulative_line
    end
  end

  def weekly_progress_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_to_date_line
    when :gas
      :targeting_and_tracking_weekly_gas_to_date_line
    when :storage_heater
      :targeting_and_tracking_weekly_storage_heater_to_date_line
    end
  end

  def weekly_progress_to_date_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_one_year_line
    when :gas
      :targeting_and_tracking_weekly_gas_one_year_line
    when :storage_heater
      :targeting_and_tracking_weekly_storage_heater_one_year_line
    end
  end

  private

  def data_headers
    data[:current_year_date_ranges].map { |r| r.first.strftime('%b') }
  end

  def data_series(key)
    data[key]
  end

  def data
    @data ||= CalculateMonthlyTrackAndTraceData.new(@aggregate_school, @fuel_type).raw_data
  end

  def target_school
    @target_school ||= @aggregate_school.target_school
  end

  def target_meter
    @target_meter ||= target_school.aggregate_meter(@fuel_type)
  end

  def aggregate_meter
    @aggregate_meter ||= @aggregate_school.aggregate_meter(@fuel_type)
  end
end