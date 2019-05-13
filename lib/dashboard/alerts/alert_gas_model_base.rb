#================= Base Class for Gas Alerts including model usage=============
require_relative 'alert_gas_only_base.rb'

class AlertGasModelBase < AlertGasOnlyBase
  include Logging
  MAX_CHANGE_IN_PERCENT = 0.15

  attr_reader :enough_data

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
    @a ||= @heating_model.average_heating_school_day_a
  end

  def b
    @b ||= @heating_model.average_heating_school_day_b
  end

  def school_days_heating
    @school_days_heating ||= @heating_model.number_of_heating_school_days
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

  protected def model_start_date(asof_date)
    asof_date_minus_one_year(asof_date)
  end

  protected def one_year_period(asof_date)
    SchoolDatePeriod.new(:alert, 'Current Year', model_start_date(asof_date), asof_date)
  end

  protected def enough_data_for_model_fit
    @heating_model = calculate_model(asof_date) if @heating_model.nil?
    @heating_model.enough_samples_for_good_fit
  end

  protected def calculate_model(asof_date)
    @heating_model = model_cache(@school.urn, asof_date)
  end

  # during analytics testing store model results to save recalculating for different alerts at same school
  private def model_cache(urn, asof_date)
    return call_model(asof_date) unless AlertAnalysisBase.test_mode
    @@model_cache_results = {} unless defined?(@@model_cache_results)
    composite_key = urn.to_s + ':' + asof_date.to_s
    return @@model_cache_results[composite_key] if @@model_cache_results.key?(composite_key)
    @@model_cache_results[composite_key] = call_model(asof_date) 
  end

  private def call_model(asof_date)
    @school.aggregated_heat_meters.model_cache.create_and_fit_model(:best, one_year_period(asof_date)) 
  end
end
