# frozen_string_literal: true

require_relative 'alert_arbitrary_period_configurable_comparison_mixin'

class AlertConfigurablePeriodElectricityComparison < AlertArbitraryPeriodComparisonElectricityBase
  include AlertArbitraryPeriodConfigurableComparisonMixIn
end
