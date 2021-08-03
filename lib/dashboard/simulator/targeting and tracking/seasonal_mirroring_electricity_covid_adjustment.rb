# correct for reduced consumption during the 3rd lockdown (Jan-Mar 2021)
# - by using data from Jan-Mar 2020 if available
# - or using data from Oct - Dec 2020 (mirrored)
class SeasonalMirroringCovidAdjustment
  def initialize(amr_data, holidays)
    @amr_data = amr_data
    @holidays = holidays
    @lockdown_start_date  = Date.new(2021, 1, 4)
    @lockdown_end_date    = Date.new(2021, 3, 7)
  end

  def enough_data_for_annual_mirror?
    @amr_data.start_date  <= @lockdown_start_date - 365 &&
    @amr_data.end_date    >= @lockdown_end_date
  end

  def enough_data_for_seasonal_mirror?
    @amr_data.start_date  <= mirrored_weeks_dates[:mirror_weeks].last.first &&
    @amr_data.end_date    >= mirrored_weeks_dates[:lockdown_weeks].last.last
  end

  def lockdown_versus_mirror_percent_change
    reduction_percent(:lockdown_weeks, :mirror_weeks)
  end

  def lockdown_versus_previous_year_percent_change
    reduction_percent(:lockdown_weeks, :previous_year_weeks)
  end

  private

  def reduction_percent(type_1, type_2)
    paired_weeks = compare_mirrored_week_average_school_day_kwhs(type_1, type_2)
    average_lockdown_kwh = paired_weeks.map { |l_v_m| l_v_m[0] }.sum / paired_weeks.length
    average_mirrored_kwh = paired_weeks.map { |l_v_m| l_v_m[1] }.sum / paired_weeks.length
    (average_mirrored_kwh - average_lockdown_kwh) / average_mirrored_kwh
  end

  def compare_mirrored_week_average_school_day_kwhs(type_1, type_2)
    mirrored_weeks_dates[type_1].map.with_index do |lockdown_week, index|
      mirrored_week = mirrored_weeks_dates[type_2][index]
      [
        average_kwh_for_daytype(lockdown_week.first, lockdown_week.last),
        average_kwh_for_daytype(mirrored_week.first, mirrored_week.last)
      ]
    end
  end

  def average_kwh_for_daytype(start_date, end_date)
    total = 0.0
    count = 0
    (start_date..end_date).each do |date|
      next if @holidays.day_type(date) != :schoolday
      if date.between?(@amr_data.start_date, @amr_data.end_date)
        total += @amr_data.one_day_kwh(date)
        count += 1
      end
    end
    total / count
  end

  def mirrored_weeks_dates
    @mirrored_weeks_dates ||= calculate_mirrored_week_dates
  end

  def calculate_mirrored_week_dates
    results = {}

    starting_sunday = Date.new(2021, 1, 3)
    ending_saturday = Date.new(2021, 3, 6)
    lockdown_weeks = classify_weeks(starting_sunday, ending_saturday, :schoolday)

    mirror_start_sunday = Date.new(2020,  9,  6)
    mirror_end_saturday = Date.new(2020, 12, 19)
    mirror_weeks = classify_weeks(mirror_start_sunday, mirror_end_saturday, :schoolday).reverse[0...lockdown_weeks.length]

    starting_sunday = Date.new(2020, 1, 5)
    ending_saturday = Date.new(2020, 3, 7)
    previous_year = classify_weeks(starting_sunday, ending_saturday, :schoolday)

    {
      lockdown_weeks:       lockdown_weeks,
      mirror_weeks:         mirror_weeks,
      previous_year_weeks:  previous_year
    }
  end

  def classify_weeks(starting_sunday, ending_saturday, type)
    weeks = []
    (starting_sunday..ending_saturday).each_slice(7) do |days|
      weeks.push(days.first..days.last) if  week_type(days.first + 1, days.last - 1) == type
    end
    weeks
  end

  def week_type(start_monday, end_friday)
    type_count = { schoolday: 0,  weekend: 0,  holiday: 0 }
    (start_monday..end_friday).each do |date|
      type_count[@holidays.day_type(date)] += 1
    end
    type_count.sort_by { |daytype, count| -count }.to_h.keys[0]
  end
end