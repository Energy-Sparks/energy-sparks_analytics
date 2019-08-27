#======================== Turn Heating On/Off ==================================
# looks at the forecast to determine whether it is a good idea to turn the
# the heating on/off
# TODO(PH,30May2018) - improve heuristics of decision, perhaps find better way
#                    - of determining whether heating is on or off
#                    - currently this is based on a live forecast but the
#                    - AMR data might be several days out of date?
require_relative 'alert_gas_model_base.rb'

class AlertHeatingOnOff < AlertGasModelBase
  include Logging
  FORECAST_DAYS_LOOKAHEAD = 5
  AVERAGE_TEMPERATURE_LIMIT = 14
  FROST_PROTECTION_TEMPERATURE = 4

  attr_reader :weather_forecast_table
  attr_reader :next_weeks_predicted_consumption_kwh, :next_weeks_predicted_consumption_£
  attr_reader :potential_saving_next_week_kwh, :potential_saving_next_week_£
  attr_reader :percent_saving_next_week
  attr_reader :last_5_school_days_consumption_kwh, :last_5_school_days_consumption_£
  attr_reader :heating_on_off_description
  attr_reader :latest_meter_data_date, :forecast_date_time
  attr_reader :days_between_forecast_and_last_meter_date

  def initialize(school)
    super(school, :turnheatingonoff)
    @forecast_data = nil
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
    potential_saving_next_week_kwh: {
      description: 'Potential saving next week (kWh) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  {kwh: :gas}
    },
    potential_saving_next_week_£: {
      description: 'Potential saving next week (£) - attempts to model benefit to turning heating off if temperatures are high enough',
      units:  :£
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
    heating_on_off_description: {
      description: 'Is the heating currently on or off: on >= 60% last 5 days, off < 60%, caveat with latest meter date',
      units:  String
    },
    latest_meter_data_date: {
      description: 'whether the heating is on or off needs caveating with gas between forecast date and last meter date',
      units:  Date
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

  private def dark_sky_forecast
    latitude, longitude = AreaNames.latitude_longitude(AreaNames.key_from_name(@school.area_name))

    raise EnergySparksUnexpectedSchoolDataConfiguration.new('Cant find latitude for school, not setup?') if latitude.nil?

    weather = DarkSkyWeatherInterface.new.weather_forecast(latitude, longitude)
    @forecast_date_time = weather[:current][:time]
    weather.delete(:current)
    weather
  end

  private def calculate_days_between_forecast_and_last_meter_date
    forecast_date = Date.new(@forecast_date_time.year, @forecast_date_time.month, @forecast_date_time.day)
    (forecast_date - @latest_meter_data_date).to_i
  end

  private def convert_forecast_to_average_overnight_daytime_temperatures_cloud_cover(weather)
    results = {}
    first_date = convert_time_to_date(weather.keys.first)
    last_date = convert_time_to_date(weather.keys.last)
    (first_date..last_date).each do |date|
      results[date] = {
        morning_temperature:  average_weather_component(weather, date, 0,  7, :temperature),
        day_temperature:      average_weather_component(weather, date, 9, 16, :temperature),
        average_temperature:  average_weather_component(weather, date, 0, 23, :temperature),
        day_cloud_cover:      average_weather_component(weather, date, 9, 16, :cloud_cover)
      }
    end
    results.keep_if { |_date, forecast| !forecast[:morning_temperature].nil? && !forecast[:day_temperature].nil? && !forecast[:day_cloud_cover].nil? }
    results
  end

  # O(N) but short, so not a problem
  private def average_weather_component(weather, date, start_hour, end_hour, type)
    sample_forecasts = weather.select { |datetime, forecast| date == convert_time_to_date(datetime) && (start_hour..end_hour).to_a.include?(datetime.hour) }
    return nil if sample_forecasts.length < 3 # if not enough data
    forecast_by_type = sample_forecasts.values.map { |samples| samples[type] }
    forecast_by_type.sum / forecast_by_type.length
  end

  private def convert_time_to_date(time)
    Date.new(time.year, time.month, time.day)
  end

  private def met_office_forecast
    area_name = @school.area_name
    MetOfficeDatapointWeatherForecast.new(area_name)
  end

  private def yahoo_forecast_deprecated
    @forecast_data = YahooWeatherForecast.new(area_name)
    if @forecast_data.forecast.nil? || @forecast_data.forecast.empty?
      Logging.logger.info 'Warning: yahoo weather forecast not working, switching to met office (less data)'
      @forecast_data = MetOfficeDatapointWeatherForecast.new(area_name)
    end
  end

  # reduces potential bill caused by making more than 1000 calls per day, a bit hacky
  private def cached_dark_sky_for_testing
    unless defined?(@@dark_sky_cache)
      filename = File.join('./TestResults/Alerts/dark_sky_forecast_cache.yaml')
      if File.exist?(filename)
        @@dark_sky_cache, @@cached_forecast_date_time = YAML::load_file(filename)
      else
        @@dark_sky_cache = dark_sky_forecast unless defined?(@@dark_sky_cache)
        @@cached_forecast_date_time = @forecast_date_time
        File.open(filename, 'w') { |f| f.write(YAML.dump([@@dark_sky_cache, @@cached_forecast_date_time])) }
      end
    end
    @forecast_date_time = @@cached_forecast_date_time
    @@dark_sky_cache
  end

  def enough_data
    (days_amr_data > 360 && enough_data_for_model_fit) ? :enough : :not_enough
  end

  # overlap of this function with rating!
  def time_of_year_relevance
    # TODO(PH, 26Aug2019) - convert the rest of this class to this infrastructure which mixes and matches forecast and historic data
    recent_temperatures = AverageHistoricOrForecastTemperatures.new(@school)
    forecast_average_temperature = recent_temperatures.calculate_average_temperature_for_week_following(@asof_date - 7)

    if heating_on_in_last_n_days(@asof_date, true) > 0 && forecast_average_temperature > 10.0
      rating = calculate_rating_from_range(10.0, 15.0, forecast_average_temperature)
      set_time_of_year_relevance(10.0 - (rating / 2.0)) # scale from 15+C(10.0 rating) to 10.0C(5.0 rating)
    elsif heating_on_in_last_n_days(@asof_date, true) == 0 && forecast_average_temperature < 12.5
      rating = calculate_rating_from_range(12.5, 7.5, forecast_average_temperature)
      set_time_of_year_relevance(10.0 - (rating / 2.0)) # scale from 12.5+C(5.0 rating) to 7.5C(10.0 rating)
    else
      set_time_of_year_relevance(2.5)
    end
  end

  private def heating_on_in_last_n_days(asof_date, on, n = 7)
    (0...n).count { |days_ago| @heating_model.heating_on?(asof_date - days_ago) == on }
  end

  private def calculate(asof_date)
    calculate_model(asof_date)

    @weather_forecast_table = []
    forecast = AlertAnalysisBase.test_mode ? cached_dark_sky_for_testing : dark_sky_forecast
    summary_forecast = convert_forecast_to_average_overnight_daytime_temperatures_cloud_cover(forecast)

    heating_on, @last_5_school_days_consumption_kwh = heating_on_generally(asof_date, 5)

    @heating_on_off_description = heating_on ? 'on' : 'off'
    @latest_meter_data_date = last_meter_data_date

    @weather_forecast_table, @potential_saving_next_week_kwh, @next_weeks_predicted_consumption_kwh = calculate_next_weeks_savings(summary_forecast, heating_on)

    @next_weeks_predicted_consumption_£ = @next_weeks_predicted_consumption_kwh * BenchmarkMetrics::GAS_PRICE
    @potential_saving_next_week_£ = @potential_saving_next_week_kwh * BenchmarkMetrics::GAS_PRICE
    @last_5_school_days_consumption_£ = @last_5_school_days_consumption_kwh * BenchmarkMetrics::GAS_PRICE
    @percent_saving_next_week = @next_weeks_predicted_consumption_kwh == 0.0 ? 0.0 : (@potential_saving_next_week_kwh / @next_weeks_predicted_consumption_kwh)

    @days_between_forecast_and_last_meter_date = calculate_days_between_forecast_and_last_meter_date

    set_savings_capital_costs_payback(4 * @potential_saving_next_week_£, 0.0) # arbitrarily set 4 weeks of savings

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

  # TODO(PH, 27Apr2019) - doesn't take into account alerts running during the holidays
  private def heating_on_generally(asof_date, last_n_school_days_count)
    days = last_n_school_days(asof_date, last_n_school_days_count)
    heating_days = days.map { |date| heating_model.heating_on?(date) ? 1 : 0 }
    percent_heating_days = heating_days.sum / last_n_school_days_count
    last_5_days_kwh =  last_n_school_days_kwh(asof_date, last_n_school_days_count)
    [percent_heating_days >= 0.6,  last_5_days_kwh.sum] # 60% criteria
  end

  private def calculate_next_weeks_savings(summary_forecast, heating_on)
    table = []
    potential_saving_next_week_kwh = 0.0
    next_weeks_predicted_consumption_kwh = 0.0

    heat_on_off_weight = heating_on ? 1 : -1

    summary_forecast.each do |date, days_forecast|
      recommendation, reduction = heating_recommendation(date, days_forecast)
      predicted_kwh, saving_kwh = predicted_saving_kwh(date, days_forecast[:average_temperature], reduction)
      next_weeks_predicted_consumption_kwh += predicted_kwh
      saving_kwh *= heat_on_off_weight
      saving_£ = saving_kwh * BenchmarkMetrics::GAS_PRICE
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

  private def predicted_saving_kwh(date, temperature, reduction)
    heating_and_non_heating_kwh = [heating_model.predicted_heating_kwh_future_date(date, temperature), 0.0].max
    non_heating_kwh = [heating_model.predicted_non_heating_kwh_future_date(date, temperature), 0.0].max
    heating_kwh = [heating_and_non_heating_kwh - non_heating_kwh, 0.0].max
    [heating_and_non_heating_kwh, reduction * heating_kwh]
  end

  # https://www.weather.gov/media/pah/ServiceGuide/A-forecast.pdf
  private def cloud_cover_description(cloud_cover_percent)
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
  private def heating_recommendation(date, days_forecast)
    occupied?(date) ? recommended_school_day_heating(date, days_forecast) : recommended_holiday_and_weekend_heating(date, days_forecast)
  end

  # the holiday or weekend model should pick up roughly the real weekend or
  # holiday usage, so the heating_reduction will apply to that, so if there is
  # no weekend heating: 1.0 times the saving of 0.0 = 0.0
  private def recommended_holiday_and_weekend_heating(date, days_forecast)
    if [days_forecast[:day_temperature], days_forecast[:morning_temperature]].min < FROST_PROTECTION_TEMPERATURE
      description = 'heating off - frost protection on'
      heating_reduction = 0.75
    else
      description = 'heating off'
      heating_reduction = 1.0
    end
    [description, heating_reduction]
  end

  private def recommended_school_day_heating(date, days_forecast)
    off_overnight, off_daytime = recommended_heating_on_off_morning_daytime(date, days_forecast)
    heating_reduction = heating_reduction_weight(off_overnight, off_daytime)
    description = heating_description(off_overnight, off_daytime)
    [description, heating_reduction]
  end

  private def recommended_heating_on_off_morning_daytime(date, days_forecast)
    daytime_off_temperature = (date.monday? ? 15.0 : 12.0) - solar_gain_adjustment(days_forecast[:day_cloud_cover])
    off_daytime = days_forecast[:day_temperature] > daytime_off_temperature
    off_overnight = days_forecast[:morning_temperature] > 10.0
    [off_overnight, off_daytime]
  end

  private def heating_reduction_weight(off_overnight, off_daytime)
    # crudely assume 50:50 split for moment
    (off_overnight ? 0.5 : 0.0) + (off_daytime ? 0.5 : 0.0)
  end

  private def heating_description(off_overnight, off_daytime)
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
  private def solar_gain_adjustment(cloud_cover)
    cloud_cover_adjustment = { # [temperature] => hours past midnight
      0.0 => 2.0,   # 2C adjustment down at 0 cloud cover
      1.0 => 0.0    # 0C adjustment at full cloud cover
    }
    Interpolate::Points.new(cloud_cover_adjustment).at(cloud_cover)
  end

  def dates_and_temperatures_display
    display = ''
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    met_office_forecast.forecast.each do |date, temperatures|
      _low, avg_temp, _high = temperatures
      # The &#176; is the HTML code for degrees celcius
      display += date.strftime("%d %B") + ' (' + avg_temp.round(1).to_s + '&#176;) '
      forecast_limit_days -= 1
      return display if forecast_limit_days.zero?
    end
    display
  end

  def average_temperature_in_period
    average_temperatures = met_office_forecast.forecast.values.reject{|x| x.nil?}.map {|temperature| temperature[1] }
    look_ahead = [FORECAST_DAYS_LOOKAHEAD, average_temperatures.length].min
    raise EnergySparksUnexpectedStateException("Not enough forecast data #{look_ahead}") if look_ahead < 3
    limited_average_temperatures = average_temperatures[0...look_ahead]
    limited_average_temperatures.inject{ |sum, el| sum + el }.to_f / limited_average_temperatures.size # average
  end
end
