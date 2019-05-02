#======================== Poor thermostatic control ==============
require_relative 'alert_gas_model_base.rb'

class AlertThermostaticControl < AlertGasModelBase
  MIN_R2 = 0.8

  attr_reader :r2_rating_out_of_10

  def initialize(school)
    super(school, :thermostaticcontrol)
  end

  def timescale
    '1 year'
  end

  def self.template_variables
    specific = {'Thermostatic Control' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    r2: {
      description: 'Average heating model regression parameter thermostatic control r2',
      units: :r2
    },
    average_schools_r2: {
      description: 'Average heating r2 of all schools',
      units: :r2
    },
    r2_rating_adjective: {
      description: 'Average heating model regression parameter thermostatic control r2 adjective',
      units: String
    },
    r2_rating_out_of_10: {
      description: 'Average heating model regression parameter thermostatic control r2 rating out of 10',
      units: Float
    },
    base_temperature: {
      description: 'Average base temperature for heating model',
      units: :temperature
    },
    thermostatic_chart: {
      description: 'Simplified version of relevant thermostatic chart',
      units: :chart
    }
  }.freeze

  def thermostatic_chart
    :thermostatic
  end
  
  def r2
    @r2 ||= @heating_model.average_heating_school_day_r2
  end

  def r2_rating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_adjective(r2)
  end

  def average_schools_r2
    AnalyseHeatingAndHotWater::HeatingModel.average_schools_r2
  end

  def r2_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_out_of_10(r2)
  end

  def base_temperature
    @base_temperature ||= @heating_model.average_base_temperature
  end

  private def calculate(asof_date)
    calculate_model(asof_date)

    @rating = r2_rating_out_of_10

    @status = @rating < 5.0 ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url('ThermostaticControl')
  end

  def analyse_private(asof_date)
    calculate(asof_date)

    @analysis_report.add_book_mark_to_base_url('ThermostaticControl')
    @analysis_report.term = :longterm
    @analysis_report.summary = 'Thermostatic control of the school is ' + r2_rating_adjective
    text = 'The thermostatic control of the heating at your school appears ' + r2_rating_adjective
    text += sprintf('at an R2 of %.2f, ', r2)
    @analysis_report.rating = r2_rating_out_of_10
    @analysis_report.status = r2 < 0.5 ? :poor : :good
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end
end