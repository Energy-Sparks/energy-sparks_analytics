class TargetDates
  def initialize(original_meter, target)
    @original_meter = original_meter
    @target = target
  end

  def to_s
    serialised_dates_for_debug
  end

  def target_start_date
    [@target.first_target_date, @original_meter.amr_data.end_date - 365].max
  end

  def target_end_date
    target_start_date + 365
  end

  def target_date_range
    target_start_date..target_end_date
  end

  # 'benchmark' = up to 1 year period of real amr_data before target_start_date
  def benchmark_start_date
    [@original_meter.amr_data.start_date, synthetic_benchmark_start_date].max
  end

  def benchmark_end_date
    [synthetic_benchmark_end_date, @original_meter.amr_data.start_date].max
  end

  def benchmark_date_range
    benchmark_start_date..benchmark_end_date
  end

  def original_meter_start_date
    @original_meter.amr_data.start_date
  end

  def original_meter_end_date
    @original_meter.amr_data.end_date
  end

  def original_meter_date_range
    original_meter_start_date..original_meter_end_date
  end

  def synthetic_benchmark_start_date
    target_start_date - 365
  end

  def synthetic_benchmark_end_date
    target_start_date - 1
  end

  def synthetic_benchmark_date_range
    synthetic_benchmark_start_date..synthetic_benchmark_end_date
  end

  def days_benchmark_data
    (benchmark_end_date - benchmark_start_date + 1).to_i
  end

  def days_target_data
    (target_end_date - target_start_date + 1).to_i
  end

  def full_years_benchmark_data?
    if @target.target_set?
      days_benchmark_data > 364
    else
      recent_data? && @original_meter.amr_data.days > 364
    end
  end

  def final_holiday_date
    hols = @original_meter.meter_collection.holidays
    hols.holidays.last.end_date
  end

  def first_holiday_date
    hols = @original_meter.meter_collection.holidays
    hols.holidays.first.start_date
  end

  def enough_holidays?
    if @target.target_set?
      final_holiday_date >= target_end_date && first_holiday_date <= synthetic_benchmark_start_date
    else
      final_holiday_date >= today + 365 && first_holiday_date <= today - 365
    end
  end

  def missing_date_range
    synthetic_benchmark_start_date..benchmark_start_date
  end

  def recent_data?
    today > Date.today - 30
  end

  def serialised_dates_for_debug
    {
      target_start_date:              target_start_date,
      target_end_date:                target_end_date,
      benchmark_start_date:           benchmark_start_date,
      benchmark_end_date:             benchmark_end_date,
      synthetic_benchmark_start_date: synthetic_benchmark_start_date,
      synthetic_benchmark_end_date:   synthetic_benchmark_end_date,
      full_years_benchmark_data:      full_years_benchmark_data?,
      original_meter_start_date:      original_meter_start_date,
      original_meter_end_date:        original_meter_end_date,
      first_holiday_date:             first_holiday_date,
      final_holiday_date:             final_holiday_date,
      enough_holidays:                enough_holidays?,
      recent_data:                    recent_data?
    }
    # or TargetDates.instance_methods(false).map { |m| [m, self.send(m)]}
  end

  private

  def today
    $ENERGYSPARKSTESTTODAYDATE || @original_meter.amr_data.end_date
  end
end
