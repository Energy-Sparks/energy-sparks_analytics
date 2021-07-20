class TargetsService
  def initialize(aggregate_school)
    @aggregate_school = aggregate_school
  end

  def monthly_progress

    full_targets_kwh = data_series(:full_targets_kwh)
    current_year_kwhs = data_series(:current_year_kwhs)
    monthly_performance = data_series(:monthly_performance, :relative_percent)

    progress_by_month = {}
    data_headers.each_with_index do |month, idx|
      progress_by_month[month] = {
        full_targets_kwh: full_targets_kwh[idx],
        current_year_kwhs: current_year_kwhs[idx],
        monthly_performance: monthly_performance[idx],
      }
    end
    progress_by_month
  end

  def cumulative_progress

    full_cumulative_targets_kwhs = data_series(:full_cumulative_targets_kwhs)
    full_cumulative_current_year_kwhs = data_series(:full_cumulative_current_year_kwhs)
    cumulative_performance = data_series(:cumulative_performance, :relative_percent)

    progress_by_month = {}
    data_headers.each_with_index do |month, idx|
      progress_by_month[month] = {
        full_cumulative_targets_kwhs: full_cumulative_targets_kwhs[idx],
        full_cumulative_current_year_kwhs: full_cumulative_current_year_kwhs[idx],
        cumulative_performance: cumulative_performance[idx],
      }
    end
    progress_by_month
  end

  def cumulative_performance
    val = data[:cumulative_performance].compact.last
    FormatEnergyUnit.format(:relative_percent, val, :html, false, true, :target)
  end

  private

  def data_headers
    data[:current_year_date_ranges].map { |r| r.first.strftime('%b') }
  end

  def data_series(key, unit = :kwh)
    data[key].map do |val|
      FormatEnergyUnit.format(:kwh, val, :html, false, true, :target)
    end
  end

  def data
    @data ||= CalculateMonthlyTrackAndTraceData.new(@aggregate_school, :electricity).raw_data
  end
end
