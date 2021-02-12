require_relative './heating_regression_models.rb'
module AnalyseHeatingAndHotWater
  # regression models associated with hot water, and
  # particularly identifying heating versus non-heating days
  class HeatingNonHeatingDisaggregationModelBase < HeatingModelTemperatureSpace
    def initialize(heat_meter, model_overrides)
      super(heat_meter, model_overrides)
    end

    def self.model_factory(type, heat_meter, model_overrides)
      case type
      when :fixed_single_value_temperature
        HeatingNonHeatingFixedValueDisaggregationModel.new(heat_meter, model_overrides)
      when :temperature_sensitive_regression_model
        HeatingNonHeatingFixedValueDisaggregationWithRegressionModel.new(heat_meter, model_overrides)
      else
        raise EnergySparksUnexpectedStateException, "Unknown heat non-heat disaggregation model #{type}"
      end
    end

    def max_non_heating_day_kwh(date)
      raise EnergySparksAbstractBaseClass, "Abstract base class for heating, non-heating model max disaggregator called #{self.class.name}"
    end

    def average_max_non_heating_day_kwh
      raise EnergySparksAbstractBaseClass, "Abstract base class for heating, non-heating model max average disaggregator called #{self.class.name}"
    end
  end

  class HeatingNonHeatingFixedValueDisaggregationOverrideModel < HeatingNonHeatingDisaggregationModelBase
    attr_reader :max_non_heating_daily_kwh
    def initialize(max_non_heating_daily_kwh)
      @max_non_heating_daily_kwh = max_non_heating_daily_kwh
    end
    def max_non_heating_day_kwh(_date); @max_non_heating_daily_kwh end
    def average_max_non_heating_day_kwh; @max_non_heating_daily_kwh end
  end

  class HeatingNonHeatingFixedValueDisaggregationModel < HeatingNonHeatingDisaggregationModelBase
    def max_non_heating_day_kwh(date)
      @max_non_heating_day_kwh.is_a?(Float) ? @max_non_heating_day_kwh : calculate_from_regression(date)
    end

    def average_max_non_heating_day_kwh
      @max_non_heating_day_kwh.is_a?(Float) ? @max_non_heating_day_kwh : model_prediction(20.0)
    end

    def calculate_max_summer_hotwater_kitchen_kwh(period)
      @max_non_heating_day_kwh = if !@model_overrides.override_max_summer_hotwater_kwh.nil?
        @model_overrides.override_max_summer_hotwater_kwh.to_f
      elsif @meter.heating_only?
        0.0
      else
        calculate_max_hotwater_only_daily_kwh(period)
      end
    end

    private

    def calculate_from_regression(_date)
      model_prediction(20.0)
    end

    def model_prediction(avg_temperature)
      calc = @max_non_heating_day_kwh[:calculation]
      # kwh tempC + 2 standard deviations
      calc.a + avg_temperature * calc.b + 2 * @max_non_heating_day_kwh[:standard_deviation]
    end

    def calculate_max_hotwater_only_daily_kwh(period)
      boiler_days, days, _boiler_off_days = boiler_on_days(period, [6, 7, 8])

      # if for more than half the days in the summer the boiler is off
      # assume heating only and set to threshold of gas kWh noise
      return @max_zero_daily_kwh if (1.0 * boiler_days.length / days.length) < 0.5

      calc, sd = regress_boiler_on_days(boiler_days)

      puts "a #{calc.a} b #{calc.b} r2 #{calc.r2} sd #{sd}"

      {
        calculation:        calc,
        standard_deviation: sd
      }
    end

    def boiler_on_days(period, list_of_months)
      days = occupied_school_days(period, list_of_months)
      boiler_days     = days.select{ |date| boiler_on?(date) }
      boiler_off_days = days.select{ |date| boiler_off?(date) }
      [boiler_days, days, boiler_off_days]
    end

    def occupied_school_days(period, list_of_months)
      (period.start_date..period.end_date).map do |date|
        occupied?(date) && list_of_months.include?(date.month) ? date : nil
      end.compact
    end

    def regress_boiler_on_days(days)
      kwhs      = days.map { |date| @amr_data.one_day_kwh(date) }
      avg_temps = days.map { |date| temperatures.average_temperature(date) }
      sd = EnergySparks::Maths.standard_deviation(kwhs)
      [regression(:summer_occupied_all_days, avg_temps, kwhs), sd]
    end
  end

  class HeatingNonHeatingFixedValueDisaggregationWithRegressionModel < HeatingNonHeatingFixedValueDisaggregationModel
    def calculate_from_regression(date)
      avg_temp = temperatures.average_temperature(date)
      [model_prediction(avg_temp), 0.0].max
    end
    def average_max_non_heating_day_kwh
      @max_non_heating_day_kwh.is_a?(Float) ? @max_non_heating_day_kwh : model_prediction(18.0)
    end
  end
end
