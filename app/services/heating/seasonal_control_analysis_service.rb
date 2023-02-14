# frozen_string_literal: true

module Heating
  class SeasonalControlAnalysisService < BaseService

    def initialize(meter_collection:)
      validate_meter_collection(meter_collection)
      @meter_collection = meter_collection
    end

    #override enough_data? check in base class
    def enough_data?
      aggregate_meter.amr_data.days > 364 &&
      enough_data_for_model_fit? && heating_model.includes_school_day_heating_models?
    end

    def seasonal_analysis
      #hash of {kwh:, £:, £current, co2: days:, degree_days:}
      analysis = sum_heating_on_warm_weather_values
      #return £current values as these are future savings
      OpenStruct.new(
        heating_on_in_warm_weather_days: analysis[:days],
        estimated_savings: CombinedUsageMetric.new(
          kwh: analysis[:kwh],
          £: analysis[:£current],
          co2: analysis[:co2]
        )
      )
    end

    private

    def sum_heating_on_warm_weather_values
      # Returns a single hash with summed values of matching keys in an array of hashes e.g.
      # an array of hashes such as [{kwh: 12}, {kwh: 6}] will return a hash {kwh: 18}
      result = Hash.new(0)
      heating_on_seasonal_analysis_warm_weather_values.each do |subhash|
        subhash.each do |type, value|
          result[type] += value
        end
      end
      result
    end

    def heating_on_seasonal_analysis_warm_weather_values
      # Returns an array of hashes with kwh, £, £current, co2, days, and degree days values
      heating_on_seasonal_analysis.values.map { |heating_on| heating_on[:heating_warm_weather] }.compact
    end

    def heating_on_seasonal_analysis
      @seasonal_analysis ||= heating_model.heating_on_seasonal_analysis
    end

    def heating_model
      @heating_model ||= calculate_heating_model
    end

    def amr_start_date
      aggregate_meter.amr_data.start_date
    end

    def amr_end_date
      aggregate_meter.amr_data.end_date
    end

    def calculate_heating_model
      period_start_date = [amr_end_date - 365, amr_start_date].max
      last_year = SchoolDatePeriod.new(:analysis, 'validate amr', period_start_date, amr_end_date)
      aggregate_meter.heating_model(last_year)
    end
  end
end
