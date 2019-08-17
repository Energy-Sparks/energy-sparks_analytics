#======================== Poor thermostatic control ==============
require_relative 'alert_gas_model_base.rb'

class AlertThermostaticControl < AlertGasModelBase
  MIN_R2 = 0.8

  attr_reader :r2_rating_out_of_10

  def initialize(school)
    super(school, :thermostaticcontrol)
    @relevance = :never_relevant if @relevance != :never_relevant && non_heating_only
  end

  def timescale
    '1 year'
  end

  def enough_data
    enough_data_for_model_fit ? :enough : :not_enough
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
  alias_method :analyse_private, :calculate
end
