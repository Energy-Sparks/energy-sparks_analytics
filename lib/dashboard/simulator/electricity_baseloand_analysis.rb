# mix of electricity baseload analysis
class ElectricityBaseloadAnalysis
  def initialize(meter)
    @meter = meter
  end

  def average_baseload(date1, date2)
    amr_data.average_baseload_kw_date_range(date1, date2)
  end

  def average_baseload_kw(asof_date)
    start_date = [asof_date - 364, amr_data.start_date].max
    average_baseload(start_date, asof_date)
  end

  def annual_average_baseload_kwh(asof_date)
    365.0 * 24.0 * average_baseload_kw(asof_date)
  end

  def annual_average_baseload_£(asof_date)
    kwh = annual_average_baseload_kwh(asof_date)
    kwh * blended_electricity_£_per_kwh(asof_date)
  end

  def one_years_data?(asof_date = amr_data.end_date)
    amr_data.days > 364
  end

  def winter_kw(asof_date = amr_data.end_date)
    average_top_n(baseload_kws_for_dates(winter_school_day_sample_dates(asof_date)), 15)
  end

  def summer_kw(asof_date = amr_data.end_date)
    average_bottom_n(baseload_kws_for_dates(summer_school_day_sample_dates(asof_date)), 15)
  end

  def percent_seasonal_variation(asof_date = amr_data.end_date)
    return nil unless one_years_data?
    kw_in_summer = summer_kw(asof_date)
    (winter_kw(asof_date) - kw_in_summer) /kw_in_summer
  end

  def costs_of_baseload_above_minimum_kwh(asof_date = amr_data.end_date, minimum)
    start_date = [asof_date - 364, amr_data.start_date].max
    baseloads_kw = amr_data.statistical_baseloads_in_date_range(start_date, amr_data.end_date)
    above_minimum = baseloads_kw.select { |kw| kw > minimum }
    above_minimum.map do |kw|
      kw * 24.0
    end.sum
  end

  private

  def baseload_kws_for_dates(dates)
    dates.map { |d| amr_data.baseload_kw(d) }
  end

  def average_top_n(baseload_kws, n)
    kws = baseload_kws.sort.last(n)
    kws.sum / kws.length
  end

  def average_bottom_n(baseload_kws, n)
    kws = baseload_kws.sort.first(n)
    kws.sum / kws.length
  end

  def summer_school_day_sample_dates(asof_date)
    sample_days_in_months(asof_date, [5, 6, 7])
  end

  def winter_school_day_sample_dates(asof_date)
    sample_days_in_months(asof_date, [11, 12, 1, 2])
  end

  def sample_days_in_months(asof_date, months_list, type = :schoolday)
    sample_dates = []
    start_date = [asof_date - 364, amr_data.start_date].max
    (start_date..amr_data.end_date).each do |date|
      sample_dates.push(date) if months_list.include?(date.month) && daytype(date) == type
    end
    sample_dates
  end

  def daytype(date)
    DateTimeHelper.daytype(date, @meter.meter_collection.holidays)
  end

  def amr_data
    @meter.amr_data
  end
end
