#======================== Heating coming on too early in morning ==============
require_relative 'alert_gas_model_base.rb'

class AlertHeatingComingOnTooEarly < AlertGasModelBase
  FROST_PROTECTION_TEMPERATURE = 4
  MAX_HALFHOURS_HEATING_ON = 10

  attr_reader :last_year_kwh, :last_year_£, :one_year_saving_£
  attr_reader :heating_on_times_table

  attr_reader :one_year_saving_£, :capital_cost
  attr_reader :one_year_optimum_start_saving_kwh, :one_year_optimum_start_saving_£
  attr_reader :percent_of_annual_gas
  
  def initialize(school)
    super(school, :heatingcomingontooearly)
  end

  def self.template_variables
    specific = {'Heating coming on too early' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    heating_on_times_table: {
      description: 'Last 7 days, heating on times and recommended heating start times with optimal start control and frost protection',
      units: :table,
      header: ['Date', 'Heating on time', 'Recommended on time', 'Overnight temperature', 'Timing', 'Potential Saving (kWh)', 'Potential Saving (£)'],
      column_types: [Date, TimeOfDay, TimeOfDay, :temperature, String, { kwh: :gas }, :£]
    },
    one_year_optimum_start_saving_kwh: {
      description: 'Estimates (up to saving) of benefit of starting boiler later in morning using a crude optimum start and frost model - kWh',
      units:  {kwh: :gas}
    },
    one_year_optimum_start_saving_£: {
      description: 'Estimates (up to saving) of benefit of starting boiler later in morning using a crude optimum start and frost model - £',
      units:  :£
    },
    percent_of_annual_gas: {
      description: 'Percent of annual gas consumption lost through coming on too early versus optimal start/frost',
      units:  :percent
    },
    annual_heating_day_intraday_profile_gas_chart: {
      description: 'Intraday profile of annual usage (£) - only heating days, not summer',
      units: :chart
    },
    last_7_days_gas_chart: {
      description: 'Last 7 days gas consumption and temperatures (suggest to user clicking off legend)',
      units: :chart
    }
  }.freeze

  def timescale
    '7 days'
  end

  def last_7_days_gas_chart
    :alert_last_7_days_intraday_gas_heating_on_too_early
  end

  def annual_heating_day_intraday_profile_gas_chart
    :alert_gas_heating_season_intraday
  end

  def calculate(asof_date)
    super(asof_date) # heating model call

    @heating_on_times_table, rating_7_day = heating_on_time_assessment(asof_date)

    @one_year_optimum_start_saving_kwh, @percent_of_annual_gas = heating_model.one_year_saving_from_better_boiler_start_time(asof_date)
    @one_year_optimum_start_saving_£ = @one_year_optimum_start_saving_kwh * BenchmarkMetrics::GAS_PRICE
 
    @one_year_saving_£ = Range.new(0.0, @one_year_optimum_start_saving_£)
    @capital_cost = Range.new(0.0, 700.0)

    @rating = [[10 - (rating_7_day + 5), 10].min, 0.0].max

    @status = @rating < 7.0 ? :bad : :good

    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('HeatingComingOnTooEarly')
  end

  private def heating_on_time_assessment(asof_date, days_countback = 7)
    days_assessment = []
    # days_assessment.push(TEMPLATE_VARIABLES[:heating_on_times_table][:header])
    rating = 0
    ((asof_date - days_countback)..asof_date).each do |date|
      heating_on_time, recommended_time, temperature, kwh_saving = heating_model.heating_on_time_assessment(date)
      kwh_saving = kwh_saving.nil? ? 0.0 : kwh_saving
      saving_£ = (kwh_saving.nil? || kwh_saving < 0.0) ? 0.0 : kwh_saving * BenchmarkMetrics::GAS_PRICE
      timing = heating_on_time.nil? ? 'no heating' : (heating_on_time > recommended_time ? 'on time' : 'too early')
      rating += heating_on_time.nil? ? 0 : (heating_on_time > recommended_time ? -1 : 1)
      days_assessment.push([date, heating_on_time, recommended_time, temperature, timing, kwh_saving, saving_£])
    end
    [days_assessment, rating]
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