require_relative './alert_period_comparison_base.rb'

class AlertPreviousYearHolidayComparisonGas < AlertPreviousYearHolidayComparisonElectricity
  include AlertPeriodComparisonTemperatureAdjustmentMixin

  def initialize(school)
    super(school, :gaspreviousyearholidaycomparison)
  end

  def self.template_variables
    specific = { 'Adjusted gas school week specific (debugging)' => holiday_adjusted_gas_variables }
    specific['Change in between last 2 holidays'] = dynamic_template_variables(:gas)
    specific['Unadjusted previous period consumption'] = self.class.unadjusted_template_variables
    specific.merge(superclass.template_variables)
  end

  def self.holiday_adjusted_gas_variables
    {}
  end

  def comparison_chart
    :alert_group_by_week_gas_14_months
  end

  protected def max_days_out_of_date_while_still_relevant
    60
  end
  
  def fuel_type; :gas end

  def calculate(asof_date)
    model_calculation(asof_date)
    super(asof_date)
    set_previous_period_unadjusted_kwh_£_co2_variables
  end
  alias_method :analyse_private, :calculate
end
