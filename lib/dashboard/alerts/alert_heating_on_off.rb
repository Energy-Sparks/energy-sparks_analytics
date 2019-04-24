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

  def initialize(school)
    super(school, :turnheatingonoff)
    @forecast_data = nil
  end

  def timescale
    'next 2 weeks'
  end

  private def dark_sky_forecast
    throw EnergySparksUnexpectedSchoolDataConfiguration.new('Unexpected null area name for school') if @school.area_name.nil?

    latitude, longitude = AreaNameGeoLocations.latitude_longitude_from_area_name(@school.area_name)

    throw EnergySparksUnexpectedSchoolDataConfiguration.new('Cant find latitude for school, not setup?') if latitude.nil?

    DarkSkyWeatherInterface.new.weather_forecast(latitude, longitude)
  end

  private def met_office_forecast
    area_name = @school.area_name

=begin
    # commented out 4Mar2019 PH - yahoo forecast deprecated?
    @forecast_data = YahooWeatherForecast.new(area_name)
    if @forecast_data.forecast.nil? || @forecast_data.forecast.empty?
      Logging.logger.info 'Warning: yahoo weather forecast not working, switching to met office (less data)'
      @forecast_data = MetOfficeDatapointWeatherForecast.new(area_name)
    end
=end
    MetOfficeDatapointWeatherForecast.new(area_name)
  end

  private def forecast
    @forecast_data = met_office_forecast
    ap(@forecast)
    @forecast_data = dark_sky_forecast if @forecast_data.nil?

    @forecast_data
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    heating_on = @heating_model.heating_on?(asof_date) # potential timing problem if AMR data not up to date

    @analysis_report = AlertReport.new(:turnheatingonoff)
    @analysis_report.add_book_mark_to_base_url('TurnHeatingOnOff')
    @analysis_report.term = :shortterm

    if heating_on && average_temperature_in_period > AVERAGE_TEMPERATURE_LIMIT
      @analysis_report.summary = 'The average temperature over the next few days is high enough to consider switching the heating off'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      @analysis_report.rating = 5.0
      @analysis_report.status = :poor
    elsif !heating_on && average_temperature_in_period < AVERAGE_TEMPERATURE_LIMIT
      @analysis_report.summary = 'The average temperature over the next few days is low enough to consider switching the heating on'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      @analysis_report.rating = 5.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'No change is necessary to the heating system'
      text = ''
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end

  def relevance
    heating_only ? :never_releant : :relevant
  end
  
  def dates_and_temperatures_display
    display = ''
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    forecast.forecast.each do |date, temperatures|
      _low, avg_temp, _high = temperatures
      # The &#176; is the HTML code for degrees celcius
      display += date.strftime("%d %B") + ' (' + avg_temp.round(1).to_s + '&#176;) '
      forecast_limit_days -= 1
      return display if forecast_limit_days.zero?
    end
    display
  end

  def average_temperature_in_period
    average_temperatures = forecast.forecast.values.reject{|x| x.nil?}.map {|temperature| temperature[1] }
    look_ahead = [FORECAST_DAYS_LOOKAHEAD, average_temperatures.length].min
    raise EnergySparksUnexpectedStateException("Not enough forecast data #{look_ahead}") if look_ahead < 3
    limited_average_temperatures = average_temperatures[0...look_ahead]
    limited_average_temperatures.inject{ |sum, el| sum + el }.to_f / limited_average_temperatures.size # average
  end
end