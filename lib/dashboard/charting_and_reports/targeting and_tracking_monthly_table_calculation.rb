# calculate up to a 2 year comparison of monthly consumption
# data versus a target
class CalculateMonthlyTrackAndTraceData
  def initialize(school, fuel_type)
    @school = school
    @fuel_type = fuel_type
    @aggregate_meter = @school.aggregate_meter(@fuel_type)
  end

  def raw_data
    @raw_data ||= calculate_raw_data
  end

  private

  def calculate_raw_data
    month_dates = academic_year_month_dates
    partial_month_dates = academic_year_month_dates_partial_month_dates(month_dates, @aggregate_meter.amr_data.end_date)

    current_year_kwhs   = kwhs_for_date_ranges(partial_month_dates, @aggregate_meter)
    full_targets_kwh    = kwhs_for_date_ranges(month_dates,         target_meter)
    partial_targets_kwh = kwhs_for_date_ranges(partial_month_dates, target_meter)
    
    full_cumulative_current_year_kwhs = accumulate(current_year_kwhs)
    partial_cumulative_targets_kwhs   = accumulate(partial_targets_kwh)

    {
      current_year_kwhs:                  current_year_kwhs,
      full_targets_kwh:                   full_targets_kwh,
      partial_targets_kwh:                kwhs_for_date_ranges(partial_month_dates, target_meter),

      full_cumulative_current_year_kwhs:  full_cumulative_current_year_kwhs,
      full_cumulative_targets_kwhs:       accumulate(full_targets_kwh),
      partial_cumulative_targets_kwhs:    partial_cumulative_targets_kwhs,

      monthly_performance:                performance(current_year_kwhs, partial_targets_kwh),
      cumulative_performance:             performance(full_cumulative_current_year_kwhs, partial_cumulative_targets_kwhs),
    
      current_year_date_ranges:           month_dates
    }
  end

  def performance(kwhs, target_kwhs)
    kwhs.map.with_index do |_kwh, i|
      kwhs[i].nil? ? nil : ((kwhs[i] - target_kwhs[i]) / target_kwhs[i])
    end
  end

  def kwhs_for_date_ranges(date_ranges, meter)
    date_ranges.map do |date_range|
      date_range.nil? ? nil : kwh_date_range(meter, date_range.first, date_range.last)
    end
  end

  def kwh_date_range(meter, start_date, end_date)
    meter.amr_data.kwh_date_range(start_date, end_date)
  end

  def academic_year_month_dates
    current_year = @school.holidays.academic_year_tolerant_of_missing_data(@aggregate_meter.amr_data.end_date)

    start_date = Date.new(current_year.start_date.year, current_year.start_date.month, 1)

    (0..11).map do |month_index|
      end_date = DateTimeHelper.last_day_of_month(start_date)
      month_date_range = start_date..end_date
      start_date = end_date + 1
      month_date_range
    end
  end

  # full months before last meter date, month_start to meter_date during month, then nils for future months
  # e.g [ 1Sep2020..30Sep2020, 1Oct2020..31Oct2020, 1Nov2020..15Nov2020, nil,nil,nil......]
  def academic_year_month_dates_partial_month_dates(month_dates, last_meter_date)
    month_dates.map do |month_date_range|
      if month_date_range.first.year == last_meter_date.year && month_date_range.first.month == last_meter_date.month
        month_date_range.first..last_meter_date
      elsif month_date_range.first > last_meter_date
        nil
      else
        month_date_range
      end
    end
  end

  def accumulate(arr)
    running_total = 0.0
    arr.map do |v|
      if v.nil?
        nil
      else
        running_total += v
      end
    end
  end

  def target_school
    @target_school ||= TargetSchool.new(@school, :day)
  end

  def target_meter
    target_school.aggregate_meter(@fuel_type)
  end
end
