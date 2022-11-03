require_relative './alert_period_comparison_base.rb'

class AlertPreviousYearHolidayComparisonGas < AlertPreviousYearHolidayComparisonElectricity
  include AlertPeriodComparisonTemperatureAdjustmentMixin
  include AlertPeriodComparisonGasMixin

  def self.template_variables
    AlertPeriodComparisonGasMixin.template_variables.merge(superclass.template_variables)
  end
  
  def initialize(school, type = :gaspreviousyearholidaycomparison)
    super(school, type)
  end

  def comparison_chart
    :alert_group_by_week_gas_14_months
  end
end
