#======================== Turn Heating On/Off ==================================
# looks at the forecast to determine whether it is a good idea to turn the
# the heating on/off
# TODO(PH,30May2018) - improve heuristics of decision, perhaps find better way
#                    - of determining whether heating is on or off
#                    - currently this is based on a live forecast but the
#                    - AMR data might be several days out of date?
require_relative '../alert_gas_model_base.rb'

class AlertHeatingOnOffBaseDeprecated < AlertGasModelBase
  include Logging
  MIN_HEATING_TEMPERATURE_MONDAY    = 15
  MIN_HEATING_TEMPERATURE_WEEKDAY   = 12
  MIN_HEATING_TEMPERATURE_OVERNIGHT = 10
  FROST_PROTECTION_TEMPERATURE      =  4

  attr_reader :weather_forecast_table
  attr_reader :next_weeks_predicted_consumption_kwh, :next_weeks_predicted_consumption_£
  attr_reader :potential_saving_next_week_kwh, :potential_saving_next_week_£
  attr_reader :percent_saving_next_week
  attr_reader :last_5_school_days_consumption_kwh, :last_5_school_days_consumption_£
  attr_reader :last_5_school_days_consumption_co2, :potential_saving_next_week_co2, :next_weeks_predicted_consumption_co2
  attr_reader :heating_on_off_description
  attr_reader :latest_meter_data_date, :forecast_date_time
  attr_reader :days_between_forecast_and_last_meter_date

  def initialize(school, type = :turnheatingonoff)
    super(school, type)
    @forecast_data = nil
    if @relevance != :never_relevant
      @relevance = relevant_on_off? ? :relevant : :never_relevant
    end
  end

  protected def max_days_out_of_date_while_still_relevant
    7
  end

  def self.template_variables
    specific = {'Heating on/off recommendations' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    weather_forecast_table: {
      description: 'Next N days weather forecast (N = ~7 for dark sky, N = ~5 for Met Office)',
      units: :table,
      header: ['Date', 'Average overnight temperature', 'Average day time temperature', 'Cloud', 
               'Type of day', 'Heating recommendation', 'Potential Saving(-cost) (kWh)', 'Potential saving(-cost) (£)'],
      column_types: [Date, :temperature, :temperature, String, String, String, { kwh: :gas }, :£]
    },
    next_weeks_predicted_consumption_kwh: {
      description: 'Predicted heating consumption (kWh) if heating left on',
      units:  {kwh: :gas}
    },
    next_weeks_predicted_consumption_£: {
      description: 'Predicted heating consumption (£) if heating left on',
      units:  :£
    },
    next_weeks_predicted_consumption_co2: {
      description: 'Predicted heating consumption (co2) if heating left on',
      units:  :co2
    },
    potential_saving_next_week_kwh: {
      description: 'Potential saving next week (kWh) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  {kwh: :gas}
    },
    potential_saving_next_week_£: {
      description: 'Potential saving next week (£) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  :£
    },
    potential_saving_next_week_co2: {
      description: 'Potential saving next week (co2) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  :co2
    },
    percent_saving_next_week: {
      description: 'Potential saving next week (%) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  :percent
    },
    last_5_school_days_consumption_kwh: {
      description: 'Gas consumption (kWh) for the last 5 school days (skips holidays, weekends)',
      units:  {kwh: :gas}
    },
    last_5_school_days_consumption_£: {
      description: 'Gas consumption (£) for the last 5 school days (skips holidays, weekends)',
      units:  :£
    },
    last_5_school_days_consumption_co2: {
      description: 'Gas consumption (co2) for the last 5 school days (skips holidays, weekends)',
      units:  :co2
    },
    heating_on_off_description: {
      description: 'Is the heating currently on or off: on >= 60% last 5 days, off < 60%, caveat with latest meter date',
      units:  String
    },
    latest_meter_data_date: {
      description: 'whether the heating is on or off needs caveating with gas between forecast date and last meter date',
      units:  :date
    },
    forecast_date_time: {
      description: 'date time when we picked up the weather forecast from dark sky',
      units:  Time
    },
    days_between_forecast_and_last_meter_date: {
      description: 'days between forecast date and last meter date',
      units:  Integer
    }
  }

  def timescale
    'next week'
  end

  def enough_data
    enough_data_for_model_fit ? :enough : :not_enough
  end

  # override gas model base class which strangely sets default 2.5 value
  # on calling this method
  def time_of_year_relevance
    @time_of_year_relevance
  end

  private

  def calculate(asof_date)
    calculate_model(asof_date)

    @weather_forecast_table = []

    forecast = WeatherForecast.nearest_cached_forecast_factory(asof_date, @school.latitude, @school.longitude)
    
    forecast = WeatherForecast.truncated_forecast(forecast, analysis_horizon_date(forecast.start_date))

    summary_forecast = convert_forecast_to_average_overnight_daytime_temperatures_cloud_cover(forecast)

    heating_on, @last_5_school_days_consumption_kwh = heating_on_generally(asof_date, 5)

    @heating_on_off_description = heating_on ? 'on' : 'off'
    @latest_meter_data_date = last_meter_data_date

    @weather_forecast_table, @potential_saving_next_week_kwh, @next_weeks_predicted_consumption_kwh = calculate_next_weeks_savings(summary_forecast, heating_on)

    toy_relevance = calculate_time_of_year_relevance(summary_forecast)
    set_time_of_year_relevance(toy_relevance ? 10.0 : 0.0)

    @next_weeks_predicted_consumption_£ = @next_weeks_predicted_consumption_kwh * BenchmarkMetrics.pricing.gas_price
    @potential_saving_next_week_£ = @potential_saving_next_week_kwh * BenchmarkMetrics.pricing.gas_price
    @last_5_school_days_consumption_£ = @last_5_school_days_consumption_kwh * BenchmarkMetrics.pricing.gas_price
    @percent_saving_next_week = @next_weeks_predicted_consumption_kwh == 0.0 ? 0.0 : (@potential_saving_next_week_kwh / @next_weeks_predicted_consumption_kwh)

    @next_weeks_predicted_consumption_co2 = @next_weeks_predicted_consumption_kwh * EnergyEquivalences::UK_GAS_CO2_KG_KWH
    @potential_saving_next_week_co2       = @potential_saving_next_week_kwh       * EnergyEquivalences::UK_GAS_CO2_KG_KWH
    @last_5_school_days_consumption_co2   = @last_5_school_days_consumption_kwh   * EnergyEquivalences::UK_GAS_CO2_KG_KWH

    @days_between_forecast_and_last_meter_date = days_between_forecast_and_last_meter_date(forecast)

    set_savings_capital_costs_payback(4 * @potential_saving_next_week_£, 0.0, 4 * @potential_saving_next_week_co2) # arbitrarily set 4 weeks of savings

    if @days_between_forecast_and_last_meter_date > 10
      @rating = 0 # special case, data out of date/stale
    else
      if @percent_saving_next_week >= 0.0
        @rating = calculate_rating_from_range(0.0, 1.0, @percent_saving_next_week)
      else
        @rating = calculate_rating_from_range(-1.0, 0.0, @percent_saving_next_week)
      end
      @rating = 0.1 if rating < 0.1 # distinguish between 0.0 rating, and stale meter data case above
    end

    @status = @rating < 7.0 ? :bad : :good

    @term = :shortterm
  end
  alias_method :analyse_private, :calculate

  def heating_on_in_last_n_days(asof_date, on, n = 7)
    (0...n).count { |days_ago| @heating_model.heating_on?(asof_date - days_ago) == on }
  end

  def days_between_forecast_and_last_meter_date(weather)
    (weather.start_date - @latest_meter_data_date + 1).to_i
  end

  def convert_forecast_to_average_overnight_daytime_temperatures_cloud_cover(weather)
    results = {}
    first_date = weather.start_date
    last_date  = weather.end_date

    (first_date..last_date).each do |date|
      results[date] = {
        morning_temperature:  average(weather, date, 0,  7, :temperature),
        day_temperature:      average(weather, date, 9, 16, :temperature),
        average_temperature:  average(weather, date, 0, 23, :temperature),
        day_cloud_cover:      average(weather, date, 9, 16, :cloud_cover)
      }
    end
    results.keep_if { |_date, forecast| !forecast[:morning_temperature].nil? && !forecast[:day_temperature].nil? && !forecast[:day_cloud_cover].nil? }
    results
  end

  def average(weather, date, start_hour, end_hour, type)
    weather.average_data_within_hours(date, start_hour,  end_hour, type)
  end

  # TODO(PH, 27Apr2019) - doesn't take into account alerts running during the holidays
  def heating_on_generally(asof_date, last_n_school_days_count)
    days = last_n_school_days(asof_date, last_n_school_days_count)
    heating_days = days.map { |date| heating_model.heating_on?(date) ? 1 : 0 }
    percent_heating_days = heating_days.sum / last_n_school_days_count
    last_5_days_kwh =  last_n_school_days_kwh(asof_date, last_n_school_days_count)
    [percent_heating_days >= 0.6,  last_5_days_kwh.sum] # 60% criteria
  end

  def relevant_on_off?
    calculate_model(aggregate_meter.amr_data.end_date)
    heating_on, _last_5_days_kwh = heating_on_generally(aggregate_meter.amr_data.end_date, 5)
    heating_on != heating_on_alert? # if heating on then want heating off alert, and vice versa
  end

  def calculate_next_weeks_savings(summary_forecast, heating_on)
    table = []
    potential_saving_next_week_kwh = 0.0
    next_weeks_predicted_consumption_kwh = 0.0

    heat_on_off_weight = heating_on ? 1 : -1

    summary_forecast.each do |date, days_forecast|
      recommendation, reduction = heating_recommendation(date, days_forecast)
      predicted_kwh, saving_kwh = predicted_saving_kwh(date, days_forecast[:average_temperature], reduction)
      next_weeks_predicted_consumption_kwh += predicted_kwh
      saving_kwh *= heat_on_off_weight
      saving_£ = saving_kwh * BenchmarkMetrics.pricing.gas_price
      potential_saving_next_week_kwh += saving_kwh

      table.push(
        [
          date,
          days_forecast[:morning_temperature],
          days_forecast[:day_temperature],
          cloud_cover_description(days_forecast[:day_cloud_cover]),
          occupancy_description(date),
          recommendation,
          saving_kwh,
          saving_£
        ]
      )
    end
    [table, potential_saving_next_week_kwh, next_weeks_predicted_consumption_kwh]
  end

  def predicted_saving_kwh(date, temperature, reduction)
    heating_and_non_heating_kwh = [heating_model.predicted_heating_kwh_future_date(date, temperature), 0.0].max
    non_heating_kwh = [heating_model.predicted_non_heating_kwh_future_date(date, temperature), 0.0].max
    heating_kwh = [heating_and_non_heating_kwh - non_heating_kwh, 0.0].max
    [heating_and_non_heating_kwh, reduction * heating_kwh]
  end

  # https://www.weather.gov/media/pah/ServiceGuide/A-forecast.pdf
  def cloud_cover_description(cloud_cover_percent)
    cloud_percent = (cloud_cover_percent * 100.0).to_i
    case cloud_percent
    when 88..100  then 'Cloudy/Overcast'
    when 70..87   then 'Mostly Cloudy'
    when 51..69   then 'Partly Cloudy'
    when 26..50   then 'Mostly Sunny'
    when 0..25    then 'Sunny'
    else; "Error #{cloud_percent}"
    end
  end

  # this is pending the building simulator and a proper interaction
  # of thermal mass, occupancy and solar and other gains
  def heating_recommendation(date, days_forecast)
    occupied?(date) ? recommended_school_day_heating(date, days_forecast) : recommended_holiday_and_weekend_heating(date, days_forecast)
  end

  # the holiday or weekend model should pick up roughly the real weekend or
  # holiday usage, so the heating_reduction will apply to that, so if there is
  # no weekend heating: 1.0 times the saving of 0.0 = 0.0
  def recommended_holiday_and_weekend_heating(date, days_forecast)
    if [days_forecast[:day_temperature], days_forecast[:morning_temperature]].min < FROST_PROTECTION_TEMPERATURE
      description = 'heating off - frost protection on'
      heating_reduction = 0.75
    else
      description = 'heating off'
      heating_reduction = 1.0
    end
    [description, heating_reduction]
  end

  def recommended_school_day_heating(date, days_forecast)
    off_overnight, off_daytime = recommended_heating_on_off_morning_daytime(date, days_forecast)
    heating_reduction = heating_reduction_weight(off_overnight, off_daytime)
    description = heating_description(off_overnight, off_daytime)
    [description, heating_reduction]
  end

  def recommended_heating_on_off_morning_daytime(date, days_forecast)
    daytime_off_temperature = min_heating_temperature(date) - solar_gain_adjustment(days_forecast[:day_cloud_cover])
    off_daytime = days_forecast[:day_temperature] > daytime_off_temperature
    off_overnight = days_forecast[:morning_temperature] > MIN_HEATING_TEMPERATURE_OVERNIGHT
    [off_overnight, off_daytime]
  end

  def min_heating_temperature(date)
    date.monday? ? MIN_HEATING_TEMPERATURE_MONDAY : MIN_HEATING_TEMPERATURE_WEEKDAY
  end

  def heating_reduction_weight(off_overnight, off_daytime)
    # crudely assume 50:50 split for moment
    (off_overnight ? 0.5 : 0.0) + (off_daytime ? 0.5 : 0.0)
  end

  def heating_description(off_overnight, off_daytime)
    case [off_overnight, off_daytime]
    when [true,  true]  then 'heating off'
    when [true,  false] then 'heating on in morning only starting at 08:00' # unusual; warm night, colder day
    when [false, true]  then 'heating on in morning until 09:30'
    when [false, false] then 'heating on'
    else
      raise EnergySparksUnexpectedStateException.new("Unexpected boolean combination in heating recommendation #{off_overnight} + #{off_daytime}")
    end
  end

  # pending building simulator, doesn't take into account time of day......many caveats
  def solar_gain_adjustment(cloud_cover)
    cloud_cover_adjustment = { # [temperature] => hours past midnight
      0.0 => 2.0,   # 2C adjustment down at 0 cloud cover
      1.0 => 0.0    # 0C adjustment at full cloud cover
    }
    Interpolate::Points.new(cloud_cover_adjustment).at(cloud_cover)
  end

  # at weekend just look forward to the coming week
  # for weekdays look forward to the Saturday of the week afterwards
  def analysis_horizon_date(asof_date)
    case asof_date.wday
    when 6
      asof_date + 7
    when 0
      asof_date + 6
    when 1..5
      asof_date + (6 - asof_date.wday) + 7
    end
  end
end

# typically fires in Autumn when weather cold enough to turn heating on
class AlertHeatingOnDeprecated < AlertHeatingOnOffBase
  def heating_on_alert?
    true
  end

  # if the heating is recommended to be on on > 50% of school days
  def calculate_time_of_year_relevance(summary_forecast)
    school_day_dates = summary_forecast.keys.select { |d| @school.holidays.occupied?(d) }
    return 0.0 if school_day_dates.empty?

    days_recommended_on = school_day_dates.count do |date|
      off_overnight, off_daytime = recommended_heating_on_off_morning_daytime(date, summary_forecast[date])
      recommend_heating_on = !off_overnight || !off_daytime
    end
  end
end

