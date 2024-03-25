# frozen_string_literal: true

module AlertArbitraryPeriodConfigurableComparisonMixIn
  include ArbitraryPeriodComparisonMixIn

  attr_reader :comparison_configuration

  def analyse(*args, **kwargs)
    @comparison_configuration = kwargs[:comparison_configuration]
    super(*args, **kwargs)
  end
end
