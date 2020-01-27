#======================== Heating coming on too early in morning ==============
require_relative 'alert_gas_model_base.rb'

class AlertHeatingComingOnTooEarly < AlertGasModelBase
  FROST_PROTECTION_TEMPERATURE = 4
  MAX_HALFHOURS_HEATING_ON = 10

  attr_reader :last_year_kwh, :last_year_£
  attr_reader :heating_on_times_table

  attr_reader :one_year_optimum_start_saving_kwh, :one_year_optimum_start_saving_£
  attr_reader :percent_of_annual_gas, :avg_week_start_time
  
  def initialize(school)
    super(school, :heatingcomingontooearly)
  end

  def self.template_variables
    specific = {'Heating coming on too early' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  protected def max_days_out_of_date_while_still_relevant
    21
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
      units:  :£,
      benchmark_code: 'oss£'
    },
    avg_week_start_time: {
      description: 'Average time heating started in last week',
      units: :timeofday,
      benchmark_code: 'htst'
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
    },
  }.freeze

  def timescale
    '7 days'
  end

  def enough_data
    days_amr_data >= 7 && enough_data_for_model_fit ? :enough : :not_enough
  end

  def last_7_days_gas_chart
    :alert_last_7_days_intraday_gas_heating_on_too_early
  end

  def annual_heating_day_intraday_profile_gas_chart
    :alert_gas_heating_season_intraday
  end

  def calculate(asof_date)
    calculate_model(asof_date) # heating model call
    
    @heating_on_times_table, rating_7_day, @avg_week_start_time = heating_on_time_assessment(asof_date)

    @one_year_optimum_start_saving_kwh, @percent_of_annual_gas = heating_model.one_year_saving_from_better_boiler_start_time(asof_date)
    @one_year_optimum_start_saving_£ = @one_year_optimum_start_saving_kwh * BenchmarkMetrics::GAS_PRICE
 
    set_savings_capital_costs_payback(Range.new(0.0, @one_year_optimum_start_saving_£), Range.new(0.0, 700.0))

    @rating = [[10 - (rating_7_day + 5), 10].min, 0.0].max

    @status = @rating < 7.0 ? :bad : :good

    @term = :shortterm
    @bookmark_url = add_book_mark_to_base_url('HeatingComingOnTooEarly')
  end
  alias_method :analyse_private, :calculate

  private def heating_on_time_assessment(asof_date, days_countback = 7)
    days_assessment = []
    start_times = []
    # days_assessment.push(TEMPLATE_VARIABLES[:heating_on_times_table][:header])
    rating = 0
    ((asof_date - days_countback)..asof_date).each do |date|
      heating_on_time, recommended_time, temperature, kwh_saving = heating_model.heating_on_time_assessment(date)
      start_times.push(heating_on_time) unless heating_on_time.nil?
      kwh_saving = kwh_saving.nil? ? 0.0 : kwh_saving
      saving_£ = (kwh_saving.nil? || kwh_saving < 0.0) ? 0.0 : kwh_saving * BenchmarkMetrics::GAS_PRICE
      timing = heating_on_time.nil? ? 'no heating' : (heating_on_time > recommended_time ? 'on time' : 'too early')
      rating += heating_on_time.nil? ? 0 : (heating_on_time > recommended_time ? -1 : 1)
      days_assessment.push([date, heating_on_time, recommended_time, temperature, timing, kwh_saving, saving_£])
    end
    average_heat_start_time = start_times.empty? ? nil : TimeOfDay.average_time_of_day(start_times)
    [days_assessment, rating, average_heat_start_time]
  end

  def halfhour_index_to_timestring(halfhour_index)
    hour = (halfhour_index / 2).to_s
    minutes = (halfhour_index / 2).floor.odd? ? '30' : '00'
    hour + ':' + minutes # hH:MM
  end
end