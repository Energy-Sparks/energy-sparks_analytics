class AdviceElectricityIntraday < AdviceElectricityBase
  def rating
    # TODO(PH, 18Dec2020) - not sure this method is actually called?
    5.0
  end

  private

  def daytype_statistics
    @statistics ||= calculate_stats
  end

  def calculate_stats
    amr_data = @school.aggregated_electricity_meters.amr_data
    @school.holidays.day_type_statistics(amr_data.start_date, amr_data.end_date)
  end

  def chart_content(chart, charts_and_html)
    case chart[:config_name]
    when :intraday_line_school_days_reduced_data
      super(chart, charts_and_html) if daytype_statistics[:schoolday] > 1
    when :intraday_line_school_days_reduced_data_versus_benchmarks
      super(chart, charts_and_html) if daytype_statistics[:schoolday] > 1
    when :intraday_line_holidays
      super(chart, charts_and_html) if daytype_statistics[:holiday] > 1
    when :intraday_line_weekends
      super(chart, charts_and_html) if daytype_statistics[:weekend] > 1
    when :intraday_line_school_last7days
      super(chart, charts_and_html) if daytype_statistics.values.sum > 1
    when :baseload_lastyear
      super(chart, charts_and_html) if daytype_statistics.values.sum > 1
    else
      raise EnergySparksUnexpectedStateException, "Unexpected chart type intraday electricity advice #{chart[:config_name]}"
    end
  end
end
