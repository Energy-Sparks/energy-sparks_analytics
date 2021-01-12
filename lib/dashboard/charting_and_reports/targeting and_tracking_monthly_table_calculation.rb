# calculate up to a 2 year comparison of monthly consumption
# data versus a target
class CalculateMonthlyTrackAndTraceData
  def initialize(school, fuel_type)
    @school = school
    @fuel_type = fuel_type
  end

  def raw_data
    @raw_data ||= calculate_raw_data
  end 

  private

  def calculate_raw_data
    basic_results = basic_raw_data

    target_results = target_data(basic_raw_data)

    cumulative_target_results = cumulative_target_data(target_results)

    combined_targets = target_results.merge(cumulative_target_results)

    interim_results = basic_results.merge(combined_targets)

    interim_results.merge(calculate_performance(interim_results))
  end

  def basic_raw_data
    previous_year, current_year = last_2_years(monthly_values)
    {
      previous_year_kwhs:                     values(previous_year),
      current_year_kwhs:                      values(current_year),
      previous_dates:                         dates(previous_year),
      full_cumulative_previous_year_kwhs:     cumulative(previous_year),
      full_cumulative_current_year_kwhs:      cumulative(current_year),
      partial_target_weights:                 partial_target_weights(current_year),
    }
  end

  def target_data(basic_raw_data)
    target_values = monthly_values(true)
    this_years_monthly_targets_kwh_x12 = target_values.values.map{ |v| v.nil? ? nil : v[:value] }.last(12)
    this_years_monthly_partial_targets_kwh_x12 = weight_partial_month_data(this_years_monthly_targets_kwh_x12, basic_raw_data[:partial_target_weights])

    {
      full_targets_kwh:    this_years_monthly_targets_kwh_x12,
      partial_targets_kwh: this_years_monthly_partial_targets_kwh_x12
    }
  end

  def target_data_deprecated(basic_raw_data)
    # previous simplistic targetting calculation:
    {
      full_targets_kwh:    targets(basic_raw_data[:previous_year_kwhs], nil),
      partial_targets_kwh: targets(basic_raw_data[:previous_year_kwhs], basic_raw_data[:partial_target_weights]),
    }
  end

  def weight_partial_month_data(kwhs_x12, weights)
    kwhs_x12.zip(weights).map { |a,b| a.nil? || b.nil? ? nil : a * b }
  end

  def cumulative_target_data(target_results)
    {
      full_cumulative_targets_kwhs:     cumulative_raw(target_results[:full_targets_kwh]),
      partial_cumulative_targets_kwhs:  nullify_trailing_identical_values(cumulative_raw(target_results[:partial_targets_kwh]))
    }
  end

  def calculate_performance(interim_results)
    {
      monthly_performance:     performance(interim_results[:current_year_kwhs],                 interim_results[:partial_targets_kwh]),
      cumulative_performance:  performance(interim_results[:full_cumulative_current_year_kwhs], interim_results[:partial_cumulative_targets_kwhs]),
    }
  end

  def calculate_prototype_interprets_charts
    extended             = chart_data(:targeting_and_tracking_monthly_electricity_internal_calculation)
    extended_cumulative  = chart_data(:targeting_and_tracking_monthly_electricity_internal_calculation_cumulative)
    truncated            = chart_data(:targeting_and_tracking_monthly_electricity_internal_calculation_unextended)
    truncated_cumulative = chart_data(:targeting_and_tracking_monthly_electricity_internal_calculation_unextended_cumulative)
    ap extended
  end

  def chart_data(chart_name)
    chart = calculate_chart(chart_name)
    {
      chart_name:       chart_name,
      months_mmm_yyyyy: chart[:x_axis],
      months_mmm:       chart[:x_axis].map { |name| name[0..2] },
      actual_kwhs:      chart[:x_data]['actual'],
      target_kwhs:      chart[:x_data]['target']
    }
  end

  def calculate_chart(chart_name)
    ChartManager.new(@school).run_standard_chart(chart_name)
  end
=begin
  def combine_chart_data(extended_to_future, trunacted_recent, extended_cumulative, truncated_cumulative)
    puts "Got here combine"
    ap extended_to_future
    ap trunacted_recent
    (0..11).each do |month_index|
      month_name = extended_to_future[:x_axis][month_index][0..2] # remove YYYY from default labelling
      actual_kwh      = extended_to_future[:x_data]['actual'][month_index]
      target_kwh_full = extended_to_future[:x_data]['target'][month_index]
      percent = month_index == trunacted_recent.length - 1 ? 1.0 : percent_days_in_month(trunacted_recent, extended_to_future, month_index)
      

    end
    extended_to_future[:x_axis].map.with_index do |x_axis_formatted_month_year, i|

  end
=end
  def percent_days_in_month(trunacted_recent, extended_to_future, month_index)
    month_dates_truncated = trunacted_recent[:x_axis_ranges][month_index]
    month_dates_full = extended_to_future[:x_axis_ranges][month_index]
    percent = (month_dates_truncated[1] - month_dates_truncated[0]) / (extended_to_future[1] - extended_to_future[0])
  end

  def performance(kwhs, partial_target_kwh)
    kwhs.map.with_index do |_kwh, i|
      kwhs.nil? ? nil : ((kwhs[i] - partial_target_kwh[i]) / partial_target_kwh[i])
    end
  end

  def monthly_values(use_target = false)
    (-23..0).map do |month|
      [
        month,
        checked_get_aggregate(use_target, {month: month}, @fuel_type, :kwh)
      ]
    end.to_h
  end

  def targets(kwhs, weights)
    kwhs.map.with_index do |kwh, i|
      set_target * kwh * weight(weights, i)
    end
  end

  def weight(weights, i)
    return 1.0 if weights.nil?
    return 0.0 if i >= weights.length
    weights[i]
  end

  def set_target
    target_attributes.nil? ? 0.95 : target_attributes[0][:target]
  end

  def target_attributes
    TargetAttributes.new(@school.aggregate_meter(@fuel_type)).attributes
  end

  def cumulative(h)
    cumulative_raw(h.values)
  end

  def cumulative_raw(arr)
    running_total = 0.0
    arr.map do |v|
      running_total += v.nil? ? 0.0 : val(v)
    end
  end

  # specifically for presenting culmulative targets
  # make future dates, where partial target identical nil
  # work backwards from end of array nullifying duplicates
  # TODO(PH, 6Jan2020) - improve implementation as a bit if a fudge at the moment
  def nullify_trailing_identical_values(arr)
    rev_arr = arr.reverse
    last_val = rev_arr[0]
    (1...rev_arr.length).each do |i|
      break unless last_val == rev_arr[i]

      rev_arr[i - 1] = nil
      last_val = rev_arr[i]
    end
    rev_arr.reverse
  end

  def values(h)
    h.values.map { |v| val(v) }
  end

  def dates(h)
    h.values.map { |v| v[:start_date]..v[:end_date] }
  end

  def target(previous_year)
    previous_year.map { |v| val(v) }
  end

  def val(value)
    value.is_a?(Hash) ? value[:value] : value
  end

  def partial_target_weights(current_year)
    current_year.values.map { |v| percent_of_month(v) }
  end

  def percent_of_month(value)
    (value[:end_date] - value[:start_date] + 1) / DateTimeHelper.days_in_month(value[:start_date]).to_f
  end

  def last_2_years(monthly_values)
    i0 = index_of_date(monthly_values, september_last_academic_year)
    previous_year = monthly_values.select{ |k, _v| (i0..(i0+11)).include?(k) }
    current_year  = monthly_values.select{ |k, _v| ((i0+12)..(i0+23)).include?(k) }
    [previous_year, current_year]
  end

  # should be replaced by meter attribute of dat
  # when targeting started
  def september_last_academic_year
    today = Date.today
    if today.month > 9
      Date.new(today.year - 1, 9, 1)
    else
      Date.new(today.year - 2, 9, 1)
    end
  end

  def index_of_date(monthly_values, date)
    monthly_values.each do |month_index, values|
      next if values.nil?
      return month_index if values[:start_date].year == date.year && values[:start_date].month == date.month
    end
    nil
  end

  def target_school
    @target_school ||= TargetSchool.new(@school, :day)
  end

  def scalar(use_target)
    @scalar_cache ||= {}
    @scalar_cache[use_target] ||= ScalarkWhCO2CostValues.new(use_target ? target_school : @school)
  end

  def checked_get_aggregate(use_target, period, fuel_type, data_type)
    begin
      scalar(use_target).scalar(period, fuel_type, data_type)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end
end
