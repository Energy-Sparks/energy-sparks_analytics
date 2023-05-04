#======================== Heating on for too many non school days of year ==============
# bit of an overlap with the day-type type breakdown
require_relative '../alert_gas_model_base.rb'

# alerts for leaving the heating on for too long over winter holidays and weekends
#NOTE: this doesn't seem to be setup in the application, as its not registered
#in the database. Should it be removed?
#Was removed from live system around 2022-04-11
class AlertHeatingOnNonSchoolDaysDeprecated < AlertHeatingDaysBase

  attr_reader :number_of_non_heating_days_last_year, :average_number_of_non_heating_days_last_year
  attr_reader :exemplar_number_of_non_heating_days_last_year
  attr_reader :non_heating_day_adjective
  attr_reader :total_kwh_on_unoccupied_days, :kwh_below_frost_on_unoccupied_days, :one_year_saving_kwh
  attr_reader :below_frost_£, :unoccupied_above_frost_£, :total_on_unoccupied_days_£, :total_on_unoccupied_days_co2
  attr_reader :unoccupied_above_frost_co2

  def initialize(school)
    super(school, :heating_on_days)
    @relevance = :never_relevant if @relevance != :never_relevant && non_heating_only
  end

  def timescale
    '1 year'
  end

  def self.template_variables
    specific = {'Non heating days' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    number_of_non_heating_days_last_year: {
      description: 'Number of days in the last year when the school was not open but the heating was left on',
      units:  :days
    },
    average_number_of_non_heating_days_last_year: {
      description: 'Average number of days in the last year when 30 schools in Energy Spark were not open but the heating was left on',
      units:  :days
    },
    exemplar_number_of_non_heating_days_last_year: {
      description: 'The number of days an exemplar school leaves their heating on when the school is unoccupied',
      units:  :days
    },
    non_heating_day_adjective: {
      description: 'Adjective describing the schools non heating day usage relative to other schools (e.g. average - 9 different adjectives)',
      units:  String
    },
    kwh_below_frost_on_unoccupied_days: {
      description: 'Gas consumption on unoccupied days, when heating left on kWh',
      units:  { kwh: :gas }
    },
    total_kwh_on_unoccupied_days: {
      description: 'kWh consumed on unoccupied days, when temperature below frost protection level (4C)',
      units:  { kwh: :gas }
    },
    below_frost_£: {
      description: 'legitimate usage of gas during last year, during frost periods £',
      units:  :£
    },
    total_on_unoccupied_days_£: {
      description: 'Total usage during unoccupied days £',
      units:  :£
    },
    total_on_unoccupied_days_co2: {
      description: 'Total carbon emissions during unoccupied days kg CO2',
      units:  :co2
    },
    unoccupied_above_frost_£: {
      description: 'Minimum saving through turning heat off on non occupied days £',
      units:  :£
    },
    unoccupied_above_frost_co2: {
      description: 'Minimum saving through turning heat off on non occupied days CO2',
      units:  :co2
    },
    heating_on_off_chart: {
      description: 'heating on off weekly chart',
      units:  :chart
    }
  }

  def heating_on_off_chart
    :heating_on_off_by_week_heating_school_non_school_days_only
  end

  private def calculate(asof_date)
    calculate_model(asof_date)
    statistics = AnalyseHeatingAndHotWater::HeatingModel # alias long name
    @breakdown = heating_day_breakdown_current_year(asof_date)

    meter_date_1_year_before = meter_date_one_year_before(@school.aggregated_heat_meters, asof_date)
    days = heating_model.number_of_non_school_heating_days_method_b(meter_date_1_year_before, asof_date)
    @number_of_non_heating_days_last_year = days

    @average_number_of_non_heating_days_last_year = statistics.average_non_school_day_heating_days
    @non_heating_day_adjective = statistics.non_school_heating_day_adjective(days)

    @kwh_below_frost_on_unoccupied_days, @total_kwh_on_unoccupied_days = calculate_heating_off_statistics(asof_date)
    @one_year_saving_kwh = @total_kwh_on_unoccupied_days - @kwh_below_frost_on_unoccupied_days

    @below_frost_£ = @kwh_below_frost_on_unoccupied_days * BenchmarkMetrics.pricing.gas_price # deprecated
    @unoccupied_above_frost_£ = @one_year_saving_kwh * BenchmarkMetrics.pricing.gas_price # deprecated
    @unoccupied_above_frost_co2 = @one_year_saving_kwh * EnergyEquivalences::UK_GAS_CO2_KG_KWH
    @total_on_unoccupied_days_£   = @total_kwh_on_unoccupied_days * BenchmarkMetrics.pricing.gas_price # deprecated
    @total_on_unoccupied_days_co2 = @total_kwh_on_unoccupied_days * EnergyEquivalences::UK_GAS_CO2_KG_KWH

    set_savings_capital_costs_payback(Range.new(@unoccupied_above_frost_£ , @unoccupied_above_frost_£), nil, @unoccupied_above_frost_co2)

    @rating = statistics.non_school_day_heating_rating_out_of_10(days)

    @exemplar_number_of_non_heating_days_last_year = 5 # TODO(PH, 2May2019) - need to work out how to calculate this from benchmarking

    @status = @rating < 5.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('HeatingOnSchoolDays')
  end
  alias_method :analyse_private, :calculate
end
