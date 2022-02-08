# calculates interpolated weighted average power consumption
# at a time - internded for CAD device target setting
class RealTimeKwTarget
  MAXMATCHDATES = 5
  MIDDLEOFBUCKET15MINS = 5 * 60 # half hour kWh reading centred 15 minutes into bucket
  SECONDSINBUCKET = 30 * 60

  # result < 2KB
  def self.interpolator(school, meter, today)
    @school = school
    calculate_interpolated_target_kw(today, school.holidays, meter.amr_data)
  end

  # t = Time, takes 0.003 ms on i5 laptop
  def self.target_kw(polator, t)
    interpolate_kw(polator, t)
  end

  private

  def self.calculate_interpolated_target_kw(today, holidays, amr_data)
    dates = matching_dates(today, holidays, amr_data.start_date, amr_data.end_date).sort
    weighted_dates = calculate_weighted_dates(dates)
    weighted_historic_kwh_x48 = calculate_weighted_kwh_x48(weighted_dates, amr_data)
    interpolate_kwh(weighted_historic_kwh_x48)
  end

  def self.calculate_weighted_dates(dates)
    weighted_dates = dates.map.with_index { |d, w| [d, w + 1] }.to_h
    total_weight = weighted_dates.values.sum
    weighted_dates.transform_values { |w| w.to_f / total_weight }
  end

  def self.interpolate_kw(interpolator, t)
    seconds_since_midnight = (t.to_i - t_to_d(t).to_i).to_f
    2.0 * interpolator.at(seconds_since_midnight)
  end

  def self.t_to_d(t)
    Time.new(t.year, t.month, t.day)
  end

  def self.interpolate_kwh(weighted_historic_kwh_x48)
    seconds_in_into_day_to_kwh = weighted_historic_kwh_x48.map.with_index { |kwh, hhi| [ hhi * SECONDSINBUCKET + MIDDLEOFBUCKET15MINS, kwh ]}.to_h
    Interpolate::Points.new(seconds_in_into_day_to_kwh)
  end

  def self.calculate_weighted_kwh_x48(weighted_dates, amr_data)
    kwh_component_x48 = weighted_dates.map do |date, weight|
      AMRData.fast_multiply_x48_x_scalar(amr_data.days_kwh_x48(date), weight)
    end

    AMRData.fast_add_multiple_x48_x_x48(kwh_component_x48)
  end

  def self.matching_dates(today, holidays, start_date, end_date)
    dates = []

    todays_day_type = holidays.day_type(today)

    date = end_date

    while date >= start_date do
      dates.push(date) if holidays.day_type(date) == todays_day_type
      break if dates.length == MAXMATCHDATES
      date -= 1
    end

    dates
  end
end
