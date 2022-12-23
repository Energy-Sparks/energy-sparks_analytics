require_relative './alert_arbitrary_period_comparison_mixin.rb'
require_relative './alert_period_comparison_gas_mixin.rb'
require_relative './alert_period_comparison_temperature_adjustment_mixin.rb'

#===================================================================================================
# Power up layer down day November 2022
module AlertLayerUpPowerdown11November2022BasicConfigMixIn
  def basic_configuration
    {
      name:                   'Layer up power down day 11 November 2022',
      max_days_out_of_date:   365,
      enough_days_data:       1,
      current_period:         Date.new(2022, 11, 11)..Date.new(2022, 11, 11),
      previous_period:        Date.new(2021, 11, 12)..Date.new(2021, 11, 12)
    }
  end
end

class AlertLayerUpPowerdown11November2022ElectricityComparison < AlertArbitraryPeriodComparisonElectricityBase
  include ArbitraryPeriodComparisonMixIn
  include AlertLayerUpPowerdown11November2022BasicConfigMixIn

  def comparison_configuration
    {
      comparison_chart:       :layerup_powerdown_11_november_2022_electricity_comparison_alert
    }.merge(basic_configuration)
  end
end

class AlertLayerUpPowerdown11November2022GasComparison < AlertArbitraryPeriodComparisonGasBase
  include ArbitraryPeriodComparisonMixIn
  include AlertLayerUpPowerdown11November2022BasicConfigMixIn

  def comparison_configuration
    {
      comparison_chart:       :layerup_powerdown_11_november_2022_gas_comparison_alert
    }.merge(basic_configuration)
  end

  def calculate(asof_date)
    super(asof_date)
  end
end

class AlertLayerUpPowerdown11November2022StorageHeaterComparison < AlertArbitraryPeriodComparisonStorageHeaterBase
  include ArbitraryPeriodComparisonMixIn
  include AlertLayerUpPowerdown11November2022BasicConfigMixIn

  def comparison_configuration
    {
      comparison_chart:       :layerup_powerdown_11_november_2022_storage_heater_comparison_alert
    }.merge(basic_configuration)
  end
end

#===================================================================================================
# Autumn term 2021-2022 comparison
module AlertAutumnTerm20212022ComparisonMixIn
  def basic_configuration
    {
      name:                   'Autumn term 2021 versus 2022 energy use comparison',
      max_days_out_of_date:   365,
      enough_days_data:       1,
      current_period:         Date.new(2022, 9, 5)..Date.new(2022, 12, 16),
      previous_period:        Date.new(2021, 9, 6)..Date.new(2021, 12, 17)
    }
  end
end

class AlertAutumnTerm20212022ElectricityComparison < AlertArbitraryPeriodComparisonElectricityBase
  include ArbitraryPeriodComparisonMixIn
  include AlertAutumnTerm20212022ComparisonMixIn

  def comparison_configuration
    {
      comparison_chart:       :autumn_term_2022_electricity_comparison_alert
    }.merge(basic_configuration)
  end
end

class AlertAutumnTerm20212022GasComparison < AlertArbitraryPeriodComparisonGasBase
  include ArbitraryPeriodComparisonMixIn
  include AlertAutumnTerm20212022ComparisonMixIn

  def comparison_configuration
    {
      comparison_chart:       :autumn_term_2022_gas_comparison_alert
    }.merge(basic_configuration)
  end
end

class AlertAutumnTerm20212022StorageHeaterComparison < AlertArbitraryPeriodComparisonStorageHeaterBase
  include ArbitraryPeriodComparisonMixIn
  include AlertAutumnTerm20212022ComparisonMixIn

  def comparison_configuration
    {
      comparison_chart:       :autumn_term_2022_storage_heater_comparison_alert
    }.merge(basic_configuration)
  end
end

#===================================================================================================
# September-November 2021-2022 comparison
module AlertSeptNov20212022ComparisonMixIn
  def basic_configuration
    {
      name:                   'Autumn term 2021 versus 2022 energy use comparison',
      max_days_out_of_date:   365,
      enough_days_data:       1,
      current_period:         Date.new(2022, 9, 1)..Date.new(2022, 11, 30),
      previous_period:        Date.new(2021, 9, 1)..Date.new(2021, 11, 30)
    }
  end
end

class AlertSeptNov20212022ElectricityComparison < AlertAutumnTerm20212022ElectricityComparison
end

class AlertSeptNov20212022GasComparison < AlertAutumnTerm20212022GasComparison
end

class AlertSeptNov20212022StorageHeaterComparison < AlertAutumnTerm20212022StorageHeaterComparison
end
