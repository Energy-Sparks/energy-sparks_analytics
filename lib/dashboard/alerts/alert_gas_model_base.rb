#================= Base Class for Gas Alerts including model usage=============
require_relative 'alert_gas_only_base.rb'

class AlertGasModelBase < AlertGasOnlyBase
  include Logging
  MAX_CHANGE_IN_PERCENT = 0.15

  attr_reader :enough_data,  :a, :b
  attr_reader :school_days_heating, :school_days_heating_adjective
  attr_reader :school_days_heating_rating_out_of_10, :average_school_heating_days
  attr_reader :non_school_days_heating, :non_school_days_heating_adjective
  attr_reader :non_school_days_heating_rating_out_of_10, :average_non_school_day_heating_days
  attr_reader :r2, :r2_rating_adjective, :r2_rating_out_of_10, :average_schools_r2
  attr_reader :base_temperature

  attr_reader :heating_model

  def initialize(school, report_type)
    super(school, report_type)
    @heating_model = nil
    @breakdown = nil
  end

  def schoolday_energy_usage_over_period(asof_date, school_days)
    total_kwh = 0.0
    while school_days > 0
      unless @school.holidays.holiday?(asof_date) || asof_date.saturday? || asof_date.sunday?
        total_kwh += days_energy_consumption(asof_date)
        school_days -= 1
      end
      asof_date -= 1
    end
    [asof_date, total_kwh]
  end

  def self.template_variables
    specific = {'Gas Model' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    enough_data: {
      description: 'Enough data for heating model calculation',
      units:  TrueClass
    },
    a: {
      description: 'Average heating model regression parameter a',
      units:  :kwh_per_day
    },
    b: {
      description: 'Average heating model regression parameter b',
      units: :kwh_per_day_per_c
    },
    r2: {
      description: 'Average heating model regression parameter thermostatic control r2',
      units: Float
    },
    average_schools_r2: {
      description: 'Average heating r2 of all schools',
      units: Float
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
    school_days_heating: {
      description: 'Number of school days of heating in the last year',
      units:  :days
    },
    school_days_heating_adjective: {
      description: 'Number of school heating days adjective (above, below average etc.)',
      units: String
    },
    school_days_heating_rating_out_of_10: {
      description: 'Number of school heating rating out of 10',
      units: Integer
    },
    average_school_heating_days: {
      description: 'Average number of school days for all schools have heating on during a year',
      units: Integer
    },
    non_school_days_heating: {
      description: 'Number of weekend, holiday days of heating in the last year',
      units:  :days
    },
    non_school_days_heating_adjective: {
      description: 'Weekend, holiday heating days adjective (above, below average etc.)',
      units: String
    },
    non_school_days_heating_rating_out_of_10: {
      description: 'Weekend, holiday heating day rating out of 10',
      units: Integer
    },
    average_non_school_day_heating_days: {
      description: 'Average weekend, holiday heating for all schools days during a year',
      units: Integer
    }
  }.freeze

  protected def days_energy_consumption(date)
    amr_data = @school.aggregated_heat_meters.amr_data
    amr_data.one_day_kwh(date)
  end

  protected def asof_date_minus_one_year(date)
    date - 364
  end

  def a
    @a ||= heating_model.average_heating_school_day_a
  end

  def b
    @b ||= @heating_model.average_heating_school_day_b
  end

  def school_days_heating
    @school_days_heating ||= heating_model.number_of_heating_school_days
  end

  def school_days_heating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.school_heating_day_adjective(school_days_heating)
  end

  def school_days_heating_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.school_day_heating_rating_out_of_10(school_days_heating)
  end

  def average_school_heating_days
    AnalyseHeatingAndHotWater::HeatingModel.average_school_heating_days
  end

  def heating_day_breakdown_current_year(asof_date)
    @breakdown = @heating_model.heating_day_breakdown(asof_date_minus_one_year(asof_date), asof_date) if @breakdown.nil?
    @breakdown
  end

  def non_school_days_heating
    @non_school_days_heating ||= @heating_model.number_of_non_school_heating_days
  end

  def non_school_days_heating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.non_school_heating_day_adjective(non_school_days_heating)
  end

  def non_school_days_heating_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.non_school_day_heating_rating_out_of_10(non_school_days_heating)
  end
  
  def average_non_school_day_heating_days
    AnalyseHeatingAndHotWater::HeatingModel.average_non_school_day_heating_days
  end

  def r2
    @r2 ||= heating_model.average_heating_school_day_r2
  end

  def r2_rating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_adjective(r2)
  end

  def average_schools_r2
    AnalyseHeatingAndHotWater::HeatingModel.average_schools_r2
  end

  def school_days_heating
    @school_days_heating ||= heating_model.number_of_heating_school_days
  end

  def base_temperature
    @base_temperature ||= @heating_model.average_base_temperature
  end

  protected def calculate_model(asof_date)
    puts 'Warning calculate_model deprecated'
    calculate(asof_date)
  end

  protected def model_start_date(asof_date)
    asof_date_minus_one_year(asof_date)
  end

  protected def one_year_period(asof_date)
    SchoolDatePeriod.new(:alert, 'Current Year', model_start_date(asof_date), asof_date)
  end

  protected def calculate_enough_data(start_date, asof_date)
    months = ((asof_date - start_date) / 30.0).floor
    @enough_data = months >= 11
  end

  protected def calculate(asof_date)
    @heating_model = @school.aggregated_heat_meters.model_cache.create_and_fit_model(:best, one_year_period(asof_date))
    calculate_enough_data(model_start_date(asof_date), asof_date)
  end
end
