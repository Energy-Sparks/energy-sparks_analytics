require 'erb'

# extension of DashboardEnergyAdvice for heating regression model fitting
class DashboardEnergyAdvice

  def self.storage_heater_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :storage_heater_group_by_week
      StorageHeaterGroupByWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_group_by_week_long_term
      StorageHeaterWeeklyLongTermAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_by_day_of_week
      StorageHeaterGasDayOfWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_intraday_current_year
      StorageHeaterGasHeatingIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_intraday_current_year_kw
      StorageHeaterGasHeatingIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :intraday_line_school_last7days_storage_heaters
      StorageHeaterLast7DaysIntradayGas.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_thermostatic
      StorageHeaterThermostaticAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :heating_on_off_by_week_storage_heater
      StorageHeaterModelFittingSplittingHeatingAndNonHeating.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class StorageHeaterGroupByWeekAdvice < GasWeeklyAdvice
=begin
    def initialize(chart_type, school, chart_definition, chart_data)
      super(chart_type, school, chart_definition, chart_data)
    end
=end
  end

  class StorageHeaterWeeklyLongTermAdvice < WeeklyLongTermAdvice
  end

  class StorageHeaterGasDayOfWeekAdvice < GasDayOfWeekAdvice
  end

  class StorageHeaterGasDayOfWeekAdvice < GasDayOfWeekAdvice
  end

  class StorageHeaterGasHeatingIntradayAdvice < GasHeatingIntradayAdvice
  end

  class StorageHeaterLast7DaysIntradayGas < Last7DaysIntradayGas
  end

  class StorageHeaterThermostaticAdvice < ThermostaticAdvice
    def initialize(school, chart_definition, chart_data, chart_symbol)
      super(school, chart_definition, chart_data, chart_symbol, :storage_heaters)
    end
  end

  class StorageHeaterModelFittingSplittingHeatingAndNonHeating < ModelFittingSplittingHeatingAndNonHeating
  end
end
