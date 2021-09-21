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

  # used by TargetsService
  def self.one_year_of_meter_readings_available_prior_to_1st_date?(original_meter)
    target = TargetAttributes.new(original_meter)
    return original_meter.amr_data.days > 365 unless target.target_set?

    target.first_target_date - original_meter.amr_data.start_date > 365
  end

    # used by TargetsService
    def self.can_calculate_one_year_of_synthetic_data?(original_meter)
      target = TargetAttributes.new(original_meter)
      return original_meter.amr_data.days > 365 unless target.target_set?
  
      # TODO(PH, 10Sep2021) - this is arbitrarily set to 30 days for the moment, refine
      if original_meter.fuel_type == :electricity
        TargetDates.minimum_5_school_days_1_weekend_meter_readings?(original_meter)
      else
        target.first_target_date - original_meter.amr_data.start_date > 30
      end
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
      @original_meter.amr_data.days > 364
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
      holiday_problems:               holiday_problems.join(', '),
      recent_data:                    recent_data?
    }
    # or TargetDates.instance_methods(false).map { |m| [m, self.send(m)]}
  end

  private

  def holiday_problems
    school = @original_meter.meter_collection
    Holidays.check_holidays(school, school.holidays, country: school.country)
  end

  def today
    $ENERGYSPARKSTESTTODAYDATE || @original_meter.amr_data.end_date
  end

  def self.minimum_5_school_days_1_weekend_meter_readings?(meter)
    holidays = meter.meter_collection.holidays
    stats = holidays.day_type_statistics(meter.amr_data.start_date, meter.amr_data.end_date)
    stats[:weekend] >= 2 && stats[:schoolday] >= 5
  end
end
