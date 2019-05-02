#======================== Heating on for too many non school days of year ==============
# bit of an overlap with the day-type type breakdown
require_relative 'alert_gas_model_base.rb'

# alerts for leaving the heating on for too long over winter holidays and weekends
class AlertHeatingOnNonSchoolDays < AlertHeatingDaysBase

  attr_reader :number_of_non_heating_days_last_year, :average_number_of_non_heating_days_last_year
  attr_reader :exemplar_number_of_non_heating_days_last_year
  attr_reader :non_heating_day_adjective
  attr_reader :total_kwh_on_unoccupied_days, :kwh_below_frost_on_unoccupied_days, :one_year_saving_kwh
  attr_reader :below_frost_£, :unoccupied_above_frost_£, :total_on_unoccupied_days_£

  def initialize(school)
    super(school, :heating_on_days)
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
    unoccupied_above_frost_£: {
      description: 'Minimum saving through turning heat off on non occupied days £',
      units:  :£
    },
    heating_on_off_chart: {
      description: 'heating on off weekly chart',
      units:  :chart
    }
  }

  def heating_on_off_chart
    :heating_on_off_by_week
  end

  private def calculate(asof_date)
    statistics = AnalyseHeatingAndHotWater::HeatingModel # alias long name
    @breakdown = heating_day_breakdown_current_year(asof_date)

    days = heating_model.number_of_non_school_heating_days
    @number_of_non_heating_days_last_year = days

    @average_number_of_non_heating_days_last_year = statistics.average_non_school_day_heating_days
    @non_heating_day_adjective = statistics.non_school_heating_day_adjective(days)

    @kwh_below_frost_on_unoccupied_days, @total_kwh_on_unoccupied_days = calculate_heating_off_statistics(asof_date)
    @one_year_saving_kwh = @total_kwh_on_unoccupied_days - @kwh_below_frost_on_unoccupied_days

    @below_frost_£ = @kwh_below_frost_on_unoccupied_days * BenchmarkMetrics::GAS_PRICE
    @unoccupied_above_frost_£ = @one_year_saving_kwh * BenchmarkMetrics::GAS_PRICE
    @total_on_unoccupied_days_£ = @total_kwh_on_unoccupied_days * BenchmarkMetrics::GAS_PRICE

    @one_year_saving_£ = Range.new(@unoccupied_above_frost_£ , @unoccupied_above_frost_£ )

    @rating = statistics.non_school_day_heating_rating_out_of_10(days)

    @exemplar_number_of_non_heating_days_last_year = 5 # TODO(PH, 2May2019) - need to work out how to calculate this from benchmarking

    @status = @rating < 5.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('HeatingOnSchoolDays')
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    calculate(asof_date)

    @analysis_report.add_book_mark_to_base_url('HeatingOnSchoolDays')

    @analysis_report.term = :longterm

    @analysis_report.summary  = 'The school has its heating for '
    @analysis_report.summary += non_school_days_heating.to_s
    @analysis_report.summary += ' weekend and holiday days each year which is '
    @analysis_report.summary += non_school_days_heating_adjective

    text = @analysis_report.summary + '.'
    kwh_saving = @breakdown[:weekend_heating_on] + @breakdown[:holiday_heating_on]
    if kwh_saving > 0
      text += ' Well managed schools typically turn their heating avoid turning their heating on over weekends and holidays.'
      text += ' If the school is only partially occupied during weekend and holiday it is often better'
      text += ' to use fan heaters rather than heating the whole school.'
      text += ' If your school followed this pattern it could save ' + FormatEnergyUnit.format(:kwh, kwh_saving)
      text += ' or ' + FormatEnergyUnit.format(:£, ConvertKwh.convert(:kwh, :£, :gas, kwh_saving)) + '.'
    end
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)

    @analysis_report.rating = school_days_heating_rating_out_of_10
    @analysis_report.status = school_days_heating > 100 ? :poor : :good
  end
end