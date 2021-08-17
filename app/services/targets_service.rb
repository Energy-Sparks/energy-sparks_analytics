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

  def relevance
    aggregate_meter.nil? ? :never_relevant : :relevant
  end

  def enough_data # or recent enough
    aggregate_meter.enough_amr_data_to_set_target? ? :enough : :not_enough
  end

  def recent_data?
    TargetMeter.recent_data?(aggregate_meter)
  end

  def enough_holidays?
    TargetMeter.enough_holidays?(aggregate_meter)
  end

  def annual_kwh_estimate_required?
    TargetMeter.annual_kwh_estimate_required?(aggregate_meter)
  end

  def valid?
    relevance == :relevant &&
    enough_data == :enough &&
    target_set? &&
    recent_data? &&
    enough_holidays?
  end

  # for backwards compatibility
  # schools without meter attributes set
  # may not be needed by front end
  def target_set?
    aggregate_meter.target_set?
  end

  def analytics_debug_info
    valid? ? target_meter.analytics_debug_info : {}
  end

  def culmulative_progress_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_to_date_cumulative_line
    when :gas
      :targeting_and_tracking_weekly_gas_to_date_cumulative_line
    when :storage_heaters, :storage_heater
      :targeting_and_tracking_weekly_storage_heater_to_date_cumulative_line
    end
  end

  def weekly_progress_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_to_date_line
    when :gas
      :targeting_and_tracking_weekly_gas_to_date_line
    when :storage_heaters, :storage_heater
      :targeting_and_tracking_weekly_storage_heater_to_date_line
    end
  end

  def weekly_progress_to_date_chart
    case @fuel_type
    when :electricity
      :targeting_and_tracking_weekly_electricity_one_year_line
    when :gas
      :targeting_and_tracking_weekly_gas_one_year_line
    when :storage_heaters, :storage_heater
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
