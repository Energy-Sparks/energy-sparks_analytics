# calculate up to a 2 year comparison of monthly consumption
# data versus a target
class CalculateMonthlyTrackAndTraceData
  def initialize(school, fuel_type)
    @school = school
    @scalar = ScalarkWhCO2CostValues.new(@school)
    @fuel_type = fuel_type
  end

  def raw_data
    @raw_data ||= calculate_raw_data
  end

  private

  def calculate_raw_data
    basic_results  = basic_raw_data

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
    {
      full_targets_kwh:    targets(basic_raw_data[:previous_year_kwhs], nil),
      partial_targets_kwh: targets(basic_raw_data[:previous_year_kwhs], basic_raw_data[:partial_target_weights]),
    }
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

  def performance(kwhs, partial_target_kwh)
    kwhs.map.with_index do |_kwh, i|
      kwhs.nil? ? nil : ((kwhs[i] - partial_target_kwh[i]) / partial_target_kwh[i])
    end
  end

  def monthly_values
    (-23..0).map do |month|
      [
        month,
        checked_get_aggregate({month: month}, @fuel_type, :kwh)
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
    @school.aggregate_meter(@fuel_type).attributes(:targeting_and_tracking)
  end

  def cumulative(h)
    cumulative_raw(h.values)
  end

  def cumulative_raw(arr)
    running_total = 0.0
    arr.map do |v|
      running_total += val(v)
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

  def checked_get_aggregate(period, fuel_type, data_type)
    begin
      @scalar.scalar(period, fuel_type, data_type)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end
end
