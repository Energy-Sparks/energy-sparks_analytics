#======================== Turn Heating On/Off ==================================
# looks at the forecast to determine whether it is a good idea to turn the
# the heating on/off
# TODO(PH,30May2018) - improve heuristics of decision, perhaps find better way
#                    - of determining whether heating is on or off
#                    - currently this is based on a live forecast but the
#                    - AMR data might be several days out of date?
require_relative 'alert_gas_model_base.rb'

class AlertHeatingOnOff < AlertGasModelBase
  FORECAST_DAYS_LOOKAHEAD = 5
  AVERAGE_TEMPERATURE_LIMIT = 14

  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)
    heating_on = @heating_model.heating_on?(asof_date) # potential timing problem if AMR data not up to date
    @yahoo_forecast = YahooWeatherForecast.new('bath, uk')

    report = AlertReport.new(:turnheatingonoff)
    report.add_book_mark_to_base_url('TurnHeatingOnOff')
    report.term = :shortterm

    if heating_on && average_temperature_in_period > AVERAGE_TEMPERATURE_LIMIT
      report.summary = 'The average temperature over the next few days is high enough to consider switching the heating off'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      report.rating = 5.0
      report.status = :poor
    elsif !heating_on && average_temperature_in_period < AVERAGE_TEMPERATURE_LIMIT
      report.summary = 'The average temperature over the next few days is low enough to consider switching the heating on'
      text = 'The following temperatures are forecast: ' + dates_and_temperatures_display
      report.rating = 5.0
      report.status = :poor
    else
      report.summary = 'No change is necessary to the heating system'
      text = ''
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  def dates_and_temperatures_display
    display = ''
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    @yahoo_forecast.forecast.each do |date, temperatures|
      _low, avg_temp, _high = temperatures
      # The &#176; is the HTML code for degrees celcius
      display += date.strftime("%d %B") + ' (' + avg_temp.to_s + '&#176;) '
      forecast_limit_days -= 1
      return display if forecast_limit_days.zero?
    end
    display
  end

  def average_temperature_in_period
    temperature_sum = 0.0
    forecast_limit_days = FORECAST_DAYS_LOOKAHEAD
    @yahoo_forecast.forecast.each_value do |temperatures|
      _low, avg_temp, _high = temperatures
      temperature_sum += avg_temp
      forecast_limit_days -= 1
      return temperature_sum / FORECAST_DAYS_LOOKAHEAD if forecast_limit_days.zero?
    end
    nil
  end
end