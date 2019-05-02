#======================== Heating on for too many school days of year ==============
require_relative 'alert_gas_model_base.rb'

# alerts for leaving the heating on for too long over winter
class AlertHeatingOnSchoolDays < AlertHeatingDaysBase

  attr_reader :number_of_heating_days_last_year, :average_number_of_heating_days_last_year
  attr_reader :exemplar_number_of_heating_days_last_year
  attr_reader :heating_day_adjective
  attr_reader :one_year_saving_reduced_days_to_average_kwh, :total_heating_day_kwh
  attr_reader :one_year_saving_reduced_days_to_exemplar_kwh
  attr_reader :one_year_saving_reduced_days_to_average_£, :one_year_saving_reduced_days_to_exemplar_£
  attr_reader :one_year_saving_reduced_days_to_average_percent, :one_year_saving_reduced_days_to_exemplar_percent
  attr_reader :one_year_saving_£

  def initialize(school)
    super(school, :heating_on_days)
  end

  def timescale
    '1 year'
  end

  def self.template_variables
    specific = {'Number of heating days in year' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    number_of_heating_days_last_year: {
      description: 'Number of days in the last year when the school was not open but the heating was left on',
      units:  :days
    },
    average_number_of_heating_days_last_year: {
      description: 'Average number of days in the last year when 30 schools in Energy Spark were not open but the heating was left on',
      units:  :days
    },
    exemplar_number_of_heating_days_last_year: {
      description: 'The number of days an exemplar school leaves their heating on when the school is unoccupied',
      units:  :days
    },
    heating_day_adjective: {
      description: 'Adjective describing the schools non heating day usage relative to other schools (e.g. average - 9 different adjectives)',
      units:  String
    },
    one_year_saving_reduced_days_to_average_kwh: {
      description: 'Saving through matching average schools heating days (turning off earlier and on later in year) kWh',
      units:  { kwh: :gas }
    },
    one_year_saving_reduced_days_to_exemplar_kwh: {
      description: 'Saving through matching exemplar schools heating days (turning off earlier and on later in year) kWh',
      units:  { kwh: :gas }
    },
    one_year_saving_reduced_days_to_average_£: {
      description: 'Saving through matching average schools heating days (turning off earlier and on later in year) £',
      units:  :£
    },
    one_year_saving_reduced_days_to_exemplar_£: {
      description: 'Saving through matching exemplar schools heating days (turning off earlier and on later in year) £',
      units:  :£
    },
    one_year_saving_reduced_days_to_average_percent: {
      description: 'Saving through matching average schools heating days (turning off earlier and on later in year) percent of annual consumption',
      units:  :percent
    },
    one_year_saving_reduced_days_to_exemplar_percent: {
      description: 'Saving through matching exemplar schools heating days (turning off earlier and on later in year) percent of annual consumption',
      units:  :percent
    },
    total_heating_day_kwh: {
      description: 'Total heating day kWh',
      units:  { kwh: :gas }
    },
    heating_on_off_chart: {
      description: 'heating on off weekly chart',
      units:  :chart
    },
  }

  def heating_on_off_chart
    :heating_on_off_by_week
  end

  private def calculate(asof_date)
    statistics = AnalyseHeatingAndHotWater::HeatingModel # alias long name
    @breakdown = heating_day_breakdown_current_year(asof_date)

    @exemplar_number_of_heating_days_last_year = 75 # TODO(PH, 2May2019) - need to work out how to calculate this from benchmarking

    days = school_days_heating
    @number_of_heating_days_last_year = days

    @average_number_of_heating_days_last_year = statistics.average_school_heating_days
    @heating_day_adjective = statistics.school_heating_day_adjective(days)

    @one_year_saving_reduced_days_to_average_kwh, @total_heating_day_kwh = calculate_heating_on_statistics(asof_date, days, @average_number_of_heating_days_last_year)
    @one_year_saving_reduced_days_to_average_percent = @one_year_saving_reduced_days_to_average_kwh / @total_heating_day_kwh

    @one_year_saving_reduced_days_to_exemplar_kwh, _total_kwh = calculate_heating_on_statistics(asof_date, days, @exemplar_number_of_heating_days_last_year)
    @one_year_saving_reduced_days_to_exemplar_percent = @one_year_saving_reduced_days_to_exemplar_kwh / @total_heating_day_kwh

    @one_year_saving_reduced_days_to_average_£ = gas_cost(@one_year_saving_reduced_days_to_average_kwh)
    @one_year_saving_reduced_days_to_exemplar_£ = gas_cost(@one_year_saving_reduced_days_to_exemplar_kwh)

    @one_year_saving_£ = Range.new(@one_year_saving_reduced_days_to_average_£ , @one_year_saving_reduced_days_to_exemplar_£)

    @rating = statistics.school_day_heating_rating_out_of_10(days)

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
    @analysis_report.summary += school_days_heating.to_s
    @analysis_report.summary += ' school days each year which is '
    @analysis_report.summary += school_days_heating_adjective

    text = @analysis_report.summary + '.'
    kwh_saving = @breakdown[:schoolday_heating_on_not_recommended]
    if kwh_saving > 0
      text += ' Well managed schools typically turn their heating on in late October and off in mid-April. '
      text += ' If your school followed this pattern it could save ' + FormatEnergyUnit.format(:kwh, kwh_saving)
      text += ' or ' + FormatEnergyUnit.format(:£, ConvertKwh.convert(:kwh, :£, :gas, kwh_saving)) + '.'
    end
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)

    @analysis_report.rating = school_days_heating_rating_out_of_10
    @analysis_report.status = school_days_heating > 100 ? :poor : :good
  end
end