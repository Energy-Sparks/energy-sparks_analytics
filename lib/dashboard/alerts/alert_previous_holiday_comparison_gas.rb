require_relative './alert_period_comparison_base.rb'

class AlertPreviousHolidayComparisonGas < AlertPreviousHolidayComparisonElectricity
  include AlertPeriodComparisonTemperatureAdjustmentMixin

  def initialize(school)
    super(school, :gaspreviousholidaycomparison)
  end

  def self.template_variables
    specific = { 'Adjusted gas school week specific (debugging)' => holiday_adjusted_gas_variables }
    specific['Change in between last 2 holidays'] = dynamic_template_variables(:gas)
    specific.merge(superclass.template_variables)
  end

  def self.holiday_adjusted_gas_variables
    {}
  end

  def comparison_chart
    :alert_group_by_week_gas_4_months
  end

  def fuel_type; :gas end

  def calculate(asof_date)
    model_calculation(asof_date)
    super(asof_date)
  end
  alias_method :analyse_private, :calculate
end
