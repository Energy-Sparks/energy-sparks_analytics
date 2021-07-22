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
      cumulative_performance: data_series(:cumulative_performance)
    )
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
end
