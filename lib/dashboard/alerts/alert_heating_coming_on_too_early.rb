#======================== Heating coming on too early in morning ==============
require_relative 'alert_gas_model_base.rb'

class AlertHeatingComingOnTooEarly < AlertGasModelBase
  FROST_PROTECTION_TEMPERATURE = 4
  MAX_HALFHOURS_HEATING_ON = 10

  def initialize(school)
    super(school, :heatingcomingontooearly)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    heating_on = @heating_model.heating_on?(asof_date) # potential timing problem if AMR data not up to date

    @analysis_report.add_book_mark_to_base_url('HeatingComingOnTooEarly')
    @analysis_report.term = :shortterm

    if heating_on
      halfhour_index = calculate_heating_on_time(asof_date, FROST_PROTECTION_TEMPERATURE)
      if halfhour_index.nil?
        @analysis_report.summary = 'Heating times: insufficient data at the moment'
        text = 'We can not work out when your heating is coming on at the moment.'
        @analysis_report.rating = 10.0
        @analysis_report.status = :good
      elsif halfhour_index < MAX_HALFHOURS_HEATING_ON
        time_str = halfhour_index_to_timestring(halfhour_index)
        @analysis_report.summary = 'Your heating is coming on too early'
        text = 'Your heating came on at ' + time_str + ' on ' + asof_date.strftime('%d %b %Y') + '.'
        @analysis_report.rating = 2.0
        @analysis_report.status = :poor
      else
        time_str = halfhour_index_to_timestring(halfhour_index)
        @analysis_report.summary = 'Your heating is coming on at a reasonable time in the morning'
        text = 'Your heating came on at ' + time_str + ' on ' + asof_date.strftime('%d %b %Y') + '.'
        @analysis_report.rating = 10.0
        @analysis_report.status = :good
      end
    else
      @analysis_report.summary = 'Check on time heating system is coming on'
      text = 'Your heating system is currently not turned on.'
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end

  # calculate when the heating comes on, using an untested heuristic to
  # determine when the heating has come on (usage > average daily usage)
  def calculate_heating_on_time(asof_date, frost_protection_temperature)
    daily_kwh = @school.aggregated_heat_meters.amr_data.one_day_kwh(asof_date)
    average_half_hourly_kwh = daily_kwh / 48.0
    (0..47).each do |halfhour_index|
      if @school.temperatures.temperature(asof_date, halfhour_index) > frost_protection_temperature &&
          @school.aggregated_heat_meters.amr_data.kwh(asof_date, halfhour_index) > average_half_hourly_kwh
        return halfhour_index
      end
    end
    nil
  end

  def halfhour_index_to_timestring(halfhour_index)
    hour = (halfhour_index / 2).to_s
    minutes = (halfhour_index / 2).floor.odd? ? '30' : '00'
    hour + ':' + minutes # hH:MM
  end
end