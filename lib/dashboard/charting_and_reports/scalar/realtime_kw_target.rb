# calculates interpolated weighted average power consumption
# at a time - internded for CAD device target setting
class RealTimeKwTarget
  MAXMATCHDATES=5

  def initialize(school, meter)
    @school = school
    @meter = meter
  end

  # t = Time
  def target_kw(t)
    @interpolated_weighted_day_x48 ||= calculate_interpolated_target_kw(t)
    interpolate_kw(@interpolated_weighted_day_x48, t)
  end
  
  private

  def calculate_interpolated_target_kw(t)
    dates = matching_dates(t).sort
    weighted_dates = calculate_weighted_dates(dates)
    weighted_historic_kwh_x48 = calculate_weighted_kwh_x48(weighted_dates)
    interpolate_kwh(t, weighted_historic_kwh_x48)
  end

  def calculate_weighted_dates(dates)
    weighted_dates = dates.map.with_index { |d, w| [d, w + 1] }.to_h
    total_weight = weighted_dates.values.sum
    weighted_dates.transform_values{ |w| w.to_f / total_weight }
  end

  def interpolate_kw(interpolator, t)
    seconds_since_midnight = (t.to_i - t_to_d(t).to_i).to_f
    2.0 * interpolator.at(seconds_since_midnight)
  end

  def t_to_d(t)
    Time.new(t.year, t.month, t.day)
  end

  def interpolate_kwh(t, weighted_historic_kwh_x48)
    seconds_in_into_day_to_kwh = weighted_historic_kwh_x48.map.with_index { |kwh, hhi| [ hhi * 30 * 60, kwh ]}.to_h
    Interpolate::Points.new(seconds_in_into_day_to_kwh)
  end

  def calculate_weighted_kwh_x48(weighted_dates)
    kwh_component_x48 = weighted_dates.map do |date, weight|
      AMRData.fast_multiply_x48_x_scalar(@meter.amr_data.days_kwh_x48(date), weight)
    end

    AMRData.fast_add_multiple_x48_x_x48(kwh_component_x48)
  end

  def matching_dates(t)
    dates = []
    today = Date.new(t.year, t.month, t.day)

    todays_day_type = @school.holidays.day_type(today)

    date = @meter.amr_data.end_date

    while date >= @meter.amr_data.start_date do
      dates.push(date) if @school.holidays.day_type(date) == todays_day_type
      break if dates.length == MAXMATCHDATES
      date -= 1
    end

    dates
  end
end