#================= Base Class for Gas Alerts including model usage=============
require_relative 'alert_analysis_base.rb'

class AlertGasModelBase < AlertAnalysisBase
  MAX_CHANGE_IN_PERCENT = 0.15

  def initialize(school)
    super(school)
    @heating_model = nil
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

  def calculate_model(asof_date)
    one_year_before_asof_date = asof_date - 365
    period = SchoolDatePeriod.new(:alert, 'Current Year', one_year_before_asof_date, asof_date)
    @heating_model = @school.heating_model(period)
    @heating_model.calculate_heating_periods(one_year_before_asof_date, asof_date)
  end
end