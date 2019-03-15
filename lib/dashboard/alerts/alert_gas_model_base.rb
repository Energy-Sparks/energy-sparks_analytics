#================= Base Class for Gas Alerts including model usage=============
require_relative 'alert_gas_only_base.rb'

class AlertGasModelBase < AlertGasOnlyBase
  include Logging
  MAX_CHANGE_IN_PERCENT = 0.15

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

  def days_energy_consumption(date)
    amr_data = @school.aggregated_heat_meters.amr_data
    amr_data.one_day_kwh(date)
  end

  def a
    @heating_model.average_heating_school_day_a
  end

  def b
    @heating_model.average_heating_school_day_b
  end

  def school_days_heating
    @heating_model.number_of_heating_school_days
  end

  def school_days_heating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.school_heating_day_adjective(school_days_heating)
  end

  def school_days_heating_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.school_day_heating_rating_out_of_10(school_days_heating)
  end

  def asof_date_minus_one_year(date)
    date - 364
  end

  def heating_day_breakdown_current_year(asof_date)
    @breakdown = @heating_model.heating_day_breakdown(asof_date_minus_one_year(asof_date), asof_date) if @breakdown.nil?
    @breakdown
  end

  def non_school_days_heating
    @heating_model.number_of_non_school_heating_days
  end

  def non_school_days_heating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.non_school_heating_day_adjective(non_school_days_heating)
  end

  def non_school_days_heating_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.non_school_day_heating_rating_out_of_10(non_school_days_heating)
  end

  def r2
    @heating_model.average_heating_school_day_r2
  end

  def r2_rating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_adjective(r2)
  end

  def r2_rating_out_of_10
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_out_of_10(r2)
  end

  def base_temperature
    @heating_model.average_base_temperature
  end

  def calculate_model(asof_date)
    if @heating_model.nil?
      period = SchoolDatePeriod.new(:alert, 'Current Year', asof_date_minus_one_year(asof_date), asof_date)
      @heating_model = @school.aggregated_heat_meters.model_cache.create_and_fit_model(:best, period)
    end
    @heating_model
  end
end