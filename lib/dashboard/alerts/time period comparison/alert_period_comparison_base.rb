require_relative './../common/alert_analysis_base.rb'
require_relative '../../utilities/energy_sparks_exceptions.rb'
# General base class for 6 alerts:
# - School week comparison: gas + electric
# - Previous holiday week comparison: gas + electric
# - Same holiday week last year comparison: gas + electric
# Generally try to recalculate periods everytime, just in case asof_date is varied in testing process
## school week, previous holiday, last year holiday comparison
#
# Relevance and enough data:
# - the alert is relevant only up to 3 weeks after the current period e.g. become irrelevant 3 weeks after a holiday
# - or for school weeks 3 weeks into a holiday
# - enough data - need enough meter data for both periods, but this can be less (6 days) than the whole period
# - so that the alert can for example signal the heating is on, if running in the middle of a holiday
# - for gas data, its also subject to enough model data for the model calculation to run
# Example as of dates for testing:
#   Whiteways: 4 Oct 2015: start of electricity, 6 Apr 2014 start of gas
#   Date.new(2015, 10, 6): all gas, but only school week relevant, no electricity
#   Date.new(2014, 7, 5): no electricity, no gas because of shortage of model data
#   Date.new(2014, 12, 1): no electricity, but should be enough model data to do school week, previous holiday, but not previous year holiday
#   Date.new(2018, 1, 1): all should be relevant
#   Date.new(2019, 3, 30): holiday alerts not relevant because towards end of term
#   Date.new(2019, 4, 3): holiday alerts not relvant because not far enough into holiday
#   Date.new(2019, 4, 10): all alerts should be relevant as far enough into holiday for enough data
#   Date.new(2019, 4, 24): all alerts should be relevant as within 3 weeks of end of holiday

class AlertPeriodComparisonBase < AlertAnalysisBase
  DAYS_ALERT_RELEVANT_AFTER_CURRENT_PERIOD = 3 * 7 # alert relevant for up to 3 weeks after period (holiday)
  # for the purposes to a 'relevant' alert we need a minimum of 6 days
  # period data, this ensures at least 1 weekend day is present for
  # the averaging process
  MINIMUM_WEEKDAYS_DATA_FOR_RELEVANT_PERIOD = 4
  MINIMUM_DIFFERENCE_FOR_NON_10_RATING_£ = 10.0
  attr_reader :difference_kwh, :difference_£, :difference_percent, :abs_difference_percent
  attr_reader :current_period_kwh, :current_period_£, :current_period_start_date, :current_period_end_date
  attr_reader :previous_period_kwh, :previous_period_£, :previous_period_start_date, :previous_period_end_date
  attr_reader :days_in_current_period, :days_in_previous_period
  attr_reader :name_of_current_period, :name_of_previous_period
  attr_reader :current_period_average_kwh, :previous_period_average_kwh
  attr_reader :current_holiday_temperatures, :current_holiday_average_temperature
  attr_reader :previous_holiday_temperatures, :previous_holiday_average_temperature
  attr_reader :current_period_kwhs, :previous_period_kwhs_unadjusted, :previous_period_average_kwh_unadjusted
  attr_reader :current_period_weekly_kwh, :current_period_weekly_£, :previous_period_weekly_kwh, :previous_period_weekly_£
  attr_reader :change_in_weekly_kwh, :change_in_weekly_£
  attr_reader :change_in_weekly_percent
  attr_reader :summary, :prefix_1, :prefix_2

  def self.dynamic_template_variables(fuel_type)
    {
      difference_kwh:     { description: 'Difference in kwh between last 2 periods', units:  { kwh: fuel_type } },
      difference_£:       { description: 'Difference in £ between last 2 periods',   units:  :£, benchmark_code: 'dif£'},
      difference_percent: { description: 'Difference in % between last 2 periods',   units:  :percent, benchmark_code: 'difp'  },
      abs_difference_percent: { description: 'Difference in % between last 2 periods - absolute, positive number only',   units:  :percent },

      current_period_kwh:        { description: 'Current period kwh',                 units:  { kwh: fuel_type } },
      current_period_£:          { description: 'Current period £',                   units:  :£  },
      current_period_start_date: { description: 'Current period start date',          units:  :date  },
      current_period_end_date:   { description: 'Current period end date',            units:  :date  },
      days_in_current_period:    { description: 'No. of days in current period',      units: Integer },
      name_of_current_period:    { description: 'name of current period e.g. Easter', units: String, benchmark_code: 'cper' },

      previous_period_kwh:        { description: 'Previous period kwh',             units:  { kwh: fuel_type } },
      previous_period_£:          { description: 'Previous period £',               units:  :£  },
      previous_period_start_date: { description: 'Previous period start date',      units:  :date  },
      previous_period_end_date:   { description: 'Previous period end date',        units:  :date  },
      days_in_previous_period:    { description: 'No. of days in previous period',  units: Integer },
      name_of_previous_period:    { description: 'name of previous period',         units: String, benchmark_code: 'pper' },

      current_period_average_kwh:  { description: 'Current period average daily kwh', units:  { kwh: fuel_type } },
      previous_period_average_kwh: { description: 'Previous period average daily',    units:  { kwh: fuel_type } },

      current_holiday_temperatures:     { description: 'Current period temperatures', units:  String  },
      previous_holiday_temperatures:    { description: 'Previous period temperatures', units:  String  },

      current_holiday_average_temperature:  { description: 'Current periods average temperature',  units:  :temperature },
      previous_holiday_average_temperature: { description: 'Previous periods average temperature', units:  :temperature },

      previous_period_average_kwh_unadjusted: { description: 'Previous period average unadjusted kwh',  units:  { kwh: fuel_type } },
      current_period_kwhs:                    { description: 'Current period kwh values', units:  String  },
      previous_period_kwhs_unadjusted:        { description: 'Previous period kwh values', units:  String  },

      current_period_weekly_kwh:  { description: 'Current period normalised average weekly kwh',   units:  { kwh: fuel_type } },
      current_period_weekly_£:    { description: 'Current period normalised average weekly £',     units:  :£  },
      previous_period_weekly_kwh: { description: 'Previous period normalised average weekly kwh',  units:  { kwh: fuel_type } },
      previous_period_weekly_£:   { description: 'Previous period normalised average weekly £',    units:  :£  },
      change_in_weekly_kwh:       { description: 'Change in normalised average weekly kwh',        units:  { kwh: fuel_type } },
      change_in_weekly_£:         { description: 'Change in normalised average weekly £',          units:  :£  },
      change_in_weekly_percent:   { description: 'Difference in weekly % between last 2 periods',  units:  :percent  },

      comparison_chart: { description: 'Relevant comparison chart', units: :chart },

      summary: { description: 'Change in £spend, relative to previous period', units: String },
      prefix_1: { description: 'Change: up or down', units: String },
      prefix_2: { description: 'Change: increase or reduction', units: String }
    }
  end

  protected def comparison_chart
    raise EnergySparksAbstractBaseClass, "Error: comparison_chart method not implemented for #{self.class.name}"
  end

  public def time_of_year_relevance
    @time_of_year_relevance ||= calculate_time_of_year_relevance(@asof_date)
  end

  def aggregate_meter
    fuel_type == :electricity ? @school.aggregated_electricity_meters : @school.aggregated_heat_meters
  end

  def timescale; 'Error- should be overridden' end

  # overridden in calculate
  def relevance
    !meter_readings_up_to_date_enough? ? :not_relevant : @relevance
  end

  def maximum_alert_date; aggregate_meter.amr_data.end_date end

  def calculate(asof_date)
    configure_models(asof_date)
    current_period, previous_period = last_two_periods(asof_date)

    # commented out 1Dec2019, in favour of alert prioritisation control
    # @relevance = time_relevance(asof_date) # during and up to 3 weeks after current period
    @relevance = (enough_periods_data(asof_date) ? :relevant : :never_relevant) if relevance == :relevant

    raise EnergySparksNotEnoughDataException, "Not enough data in current period: #{period_debug(current_period,  asof_date)}"  unless enough_days_data_for_period(current_period,  asof_date)
    raise EnergySparksNotEnoughDataException, "Not enough data in previous period: #{period_debug(previous_period,  asof_date)}" unless enough_days_data_for_period(previous_period, asof_date)

    current_period_data = meter_values_period(current_period)
    previous_period_data = normalised_period_data(current_period, previous_period)
    previous_period_data_unadjusted = meter_values_period(current_period)

    @difference_kwh     = current_period_data[:kwh] - previous_period_data[:kwh]
    @difference_£       = current_period_data[:£]   - previous_period_data[:£]
    # put in a large percent if the usage was zero during the last period
    # fixes St Louis autumn 2019 half term verus zero summer holiday -inf in benchmarking (PH, 17Dec2019)
    # reinstated (PH, 19Sep2020) - King Edwards + 1 other gas school week comparison
    @difference_percent = previous_period_data[:kwh] == 0.0 ? 1000.0 : (difference_kwh  / previous_period_data[:kwh])
    # @difference_percent = difference_kwh  / previous_period_data[:kwh]
    @abs_difference_percent = @difference_percent.magnitude

    @current_period_kwh         = current_period_data[:kwh]
    @current_period_£           = current_period_data[:£]
    @current_period_start_date  = current_period.start_date
    @current_period_end_date    = current_period.end_date
    @days_in_current_period     = current_period.days
    @name_of_current_period     = current_period_name(current_period)
    @current_period_average_kwh = @current_period_kwh / @days_in_current_period

    @previous_period_kwh          = previous_period_data[:kwh]
    @previous_period_£            = previous_period_data[:£]
    @previous_period_start_date   = previous_period.start_date
    @previous_period_end_date     = previous_period.end_date
    @days_in_previous_period      = previous_period.days
    @name_of_previous_period      = previous_period_name(previous_period)
    @previous_period_average_kwh  = @previous_period_kwh / @days_in_previous_period

    current_period_range = @current_period_start_date..@current_period_end_date
    @current_holiday_temperatures,  @current_holiday_average_temperature = weeks_temperatures(current_period_range)

    previous_period_range = @previous_period_start_date..@previous_period_end_date
    @previous_holiday_temperatures, @previous_holiday_average_temperature = weeks_temperatures(previous_period_range)

    @current_period_kwhs, _avg = formatted_kwh_period_unadjusted(previous_period_range)
    @previous_period_kwhs_unadjusted,  @previous_period_average_kwh_unadjusted = formatted_kwh_period_unadjusted(previous_period_range)

    @current_period_weekly_kwh  = normalised_average_weekly_kwh(current_period,   :kwh)
    @current_period_weekly_£    = normalised_average_weekly_kwh(current_period,   :£)
    @previous_period_weekly_kwh = normalised_average_weekly_kwh(previous_period,  :kwh)
    @previous_period_weekly_£   = normalised_average_weekly_kwh(previous_period,  :£)
    @change_in_weekly_kwh       = @current_period_weekly_kwh - @previous_period_weekly_kwh
    @change_in_weekly_£         = @current_period_weekly_£ - @previous_period_weekly_£
    @change_in_weekly_percent   = relative_change(@change_in_weekly_kwh, @previous_period_weekly_kwh)

    @prefix_1 = prefix(@difference_percent, 'up', 'the same', 'down')
    @prefix_2 = prefix(@difference_percent, 'increase', 'unchanged', 'reduction')
    @summary  = summary_text

    set_savings_capital_costs_payback(@difference_£, 0.0)
    @rating = calculate_rating(@change_in_weekly_percent, @change_in_weekly_£, fuel_type)

    @bookmark_url = add_book_mark_to_base_url(url_bookmark)
    @term = :shortterm
  end
  alias_method :analyse_private, :calculate

  private def period_debug(current_period,  asof_date)
    "#{current_period.nil? ? 'no current period' : current_period}, asof #{asof_date}"
  end

  private def period_type
    'period'
  end

  private def prefix(change, up, same, down)
    if change < 0.0
      down
    elsif change == 0.0
      same
    else
      up
    end
  end

  private def summary_text
    FormatEnergyUnit.format(:£, @difference_£, :text) + ' ' +
    @prefix_2 + ' since last ' + period_type + ', ' +
    FormatEnergyUnit.format(:relative_percent, @difference_percent, :text)
  end

  protected def calculate_rating(percentage_difference, financial_difference_£, fuel_type)
    # PH removed £10 limit 20Nov2019 at CT request
    # PH reinstated after CT request 21Dec2020
    return 10.0 if financial_difference_£.between?(-MINIMUM_DIFFERENCE_FOR_NON_10_RATING_£, MINIMUM_DIFFERENCE_FOR_NON_10_RATING_£)
    ten_rating_range_percent = fuel_type == :electricity ? 0.10 : 0.15 # more latitude for gas
    calculate_rating_from_range(-ten_rating_range_percent, ten_rating_range_percent, percentage_difference)
  end

  protected def last_two_periods(_asof_date)
    raise EnergySparksAbstractBaseClass, "Error: last_two_periods method not implemented for #{self.class.name}"
  end

  protected def fuel_type
    raise EnergySparksAbstractBaseClass, "Error: fuel_type method not implemented for #{self.class.name}"
  end

  private def url_bookmark
    fuel_type == :electricity ? 'ElectricityChange' : 'GasChange'
  end

  protected def configure_models(_asof_date)
    # do nothing in case of electricity
  end

  protected def temperature_adjustment(_date, _asof_date)
    1.0 # no adjustment for electricity, the default
  end

  protected def meter_values_period(current_period)
    {
      kwh:    kwh_date_range(aggregate_meter, current_period.start_date, current_period.end_date, :kwh),
      £:      kwh_date_range(aggregate_meter, current_period.start_date, current_period.end_date, :£)
    }
  end

  protected def normalised_period_data(current_period, previous_period)
    {
      kwh:    normalise_previous_period_data_to_current_period(current_period, previous_period, :kwh),
      £:      normalise_previous_period_data_to_current_period(current_period, previous_period, :£)
    }
  end

  private def formatted_kwh_period_unadjusted(period, data_type = :kwh)
    min_days_data_if_meter_start_date_in_holiday = 4
    values = kwhs_date_range(aggregate_meter, period.first, period.last, data_type, min_days_data_if_meter_start_date_in_holiday)
    formatted_values = values.map { |kwh| kwh.round(0) }.join(', ')
    [formatted_values, values.sum / values.length]
  end

  # adjust the previous periods electricity/gas usage to the number of days in the current period
  # by calculating the average weekday usage and average weekend usage, and multiplying
  # by the same number of days in the current holiday
  private def normalise_previous_period_data_to_current_period(current_period, previous_period, data_type)
    current_weekday_dates = SchoolDatePeriod.matching_dates_in_period_to_day_of_week_list(current_period, (1..5).to_a)
    current_weekend_dates = SchoolDatePeriod.matching_dates_in_period_to_day_of_week_list(current_period, [0, 6])

    previous_average_weekdays = average_period_value(previous_period, (1..5).to_a, data_type)
    previous_average_weekends = average_period_value(previous_period, [0, 6], data_type)

    current_weekday_dates.length * previous_average_weekdays + current_weekend_dates.length * previous_average_weekends
  end

  private def normalised_average_weekly_kwh(period, data_type)
    weekday_average = average_period_value(period, (1..5).to_a, data_type)
    weekend_average = average_period_value(period, [0, 6], data_type)
    5.0 * weekday_average + 2.0 * weekend_average
  end

  private def average_period_value(period, days_of_week, data_type)
    dates = SchoolDatePeriod.matching_dates_in_period_to_day_of_week_list(period, days_of_week)
    values = dates.map { |date| kwh_date_range(aggregate_meter, date, date, data_type) }.compact
    values.sum / values.length
  end

  protected def calculate_time_of_year_relevance(asof_date)
    current_period, previous_period = last_two_periods(asof_date)
    # lower relevance just after a holiday, only prioritise when 2 whole weeks of
    # data post holiday, use 9 days as criteria to allow for non-whole weeks post holiday
    # further modified by fuel type in derived classes so gas higher priority in winter
    # and electricity in summer (CT request 15 Sep 2020)
    days_between_school_weeks = current_period.end_date - previous_period.end_date
    school_weeks_split_either_side_of_holiday = days_between_school_weeks > 9
    meter_data_days_out_of_date = asof_date - current_period.end_date
    meter_data_out_of_date = meter_data_days_out_of_date > 10 # agreed with CT 16Sep2020
    fuel_priority = fuel_time_of_year_priority(asof_date, current_period)
    time_relevance = (meter_data_out_of_date || school_weeks_split_either_side_of_holiday) ? 1.0 : fuel_priority
    time_relevance
  end

  # relevant if asof date immediately at end of period or up to
  # 3 weeks after
  private def time_relevance_deprecated(asof_date)
    current_period, _previous_period = last_two_periods(asof_date)
    return :never_relevant if current_period.nil?
    # relevant during period, subject to 'enough_data'
    return :relevant if enough_days_in_period(current_period, asof_date)
    days_from_end_of_period_to_asof_date = asof_date - current_period.end_date
    return days_from_end_of_period_to_asof_date.between?(0, DAYS_ALERT_RELEVANT_AFTER_CURRENT_PERIOD) ? :relevant : :never_relevant
  end

  private def enough_periods_data(asof_date)
    current_period, previous_period = last_two_periods(asof_date)
    !current_period.nil? && !previous_period.nil? 
  end

  private def enough_days_in_period(period, asof_date)
    asof_date.between?(period.start_date, period.end_date) && enough_days_data(asof_date - period.start_date + 1)
  end

  def enough_data
    return :not_enough if @not_enough_data_exception
    period1, period2 = last_two_periods(@asof_date)
    enough_days_data_for_period(period1, @asof_date) && enough_days_data_for_period(period2, @asof_date) ? :enough : :not_enough
  end

  protected def enough_days_data_for_period(period, asof_date)
    return false if period.nil?
    period_start = [aggregate_meter.amr_data.start_date,  period.start_date].max
    period_end   = [aggregate_meter.amr_data.end_date,    period.end_date, asof_date].min
    enough_days_data(SchoolDatePeriod.weekdays_inclusive(period_start, period_end))
  end

  private def enough_days_data(days)
    days >= MINIMUM_WEEKDAYS_DATA_FOR_RELEVANT_PERIOD
  end

  protected def minimum_days_for_period
    MINIMUM_WEEKDAYS_DATA_FOR_RELEVANT_PERIOD
  end

  # returns [ formatted string of 7 temperatures, average for week]
  private def weeks_temperatures(date_range)
    temperatures = date_range.to_a.map { |date| @school.temperatures.average_temperature(date) }
    formatted_temperatures = temperatures.map { |temp| FormatEnergyUnit.format(:temperature, temp) }.join(', ')
    [formatted_temperatures, temperatures.sum / temperatures.length]
  end
end

class AlertHolidayComparisonBase < AlertPeriodComparisonBase
  private def period_type
    'holiday'
  end

  protected def truncate_period_to_available_meter_data(period)
    return period if period.start_date >= aggregate_meter.amr_data.start_date && period.end_date <= aggregate_meter.amr_data.end_date
    start_date = [period.start_date, aggregate_meter.amr_data.start_date].max
    end_date = [period.end_date, aggregate_meter.amr_data.end_date].min
    return SchoolDatePeriod.new(period.type, "#{period.title} truncated to available meter data", start_date, end_date) if end_date >= start_date
    nil
  end

  # relevant if asof date immediately at end of period or up to
  # 3 weeks after
  private def calculate_time_of_year_relevance(asof_date)
    current_period, _previous_period = last_two_periods(asof_date)
    return 0.0 if current_period.nil?
    # relevant during period, subject to 'enough_data'
    return 10.0 if enough_days_in_period(current_period, asof_date)
    days_from_end_of_period_to_asof_date = asof_date - current_period.end_date
    return 0.0 if days_from_end_of_period_to_asof_date > DAYS_ALERT_RELEVANT_AFTER_CURRENT_PERIOD
    percent_into_post_holiday_period = (days_from_end_of_period_to_asof_date - DAYS_ALERT_RELEVANT_AFTER_CURRENT_PERIOD) / DAYS_ALERT_RELEVANT_AFTER_CURRENT_PERIOD
    weight =  percent_into_post_holiday_period * 2.5
    10.0 - weight # scale down relevance of holiday comparison from 10.0 to 7.5 over relevance period (e.g. 3 weeks)
  end

  protected def current_period_name(current_period); period_name(current_period) end
  protected def previous_period_name(previous_period); period_name(previous_period) end

  protected def period_name(period); period.type.to_s.humanize end
end
