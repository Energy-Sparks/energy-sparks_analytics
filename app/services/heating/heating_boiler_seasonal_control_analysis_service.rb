# frozen_string_literal: true

module Heating
  class HeatingBoilerSeasonalControlAnalysisService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
      OpenStruct.new(sum_heating_on_warm_weather_values)
    end

    private

    def heating_on_seasonal_analysis_warm_weather_values
      # Returns an array of hashes with kwh, £, £current, co2, days, and degree days values
      seasonal_analysis.values.map { |heating_on| heating_on[:heating_warm_weather] }.compact
    end

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

    def seasonal_analysis
      @seasonal_analysis ||= heating_model.heating_on_seasonal_analysis
    end

    def heating_model
      @heating_model ||= calculate_heating_model
    end

    def calculate_heating_model
      start_date = [aggregated_heat_meters.amr_data.end_date - 365, aggregated_heat_meters.amr_data.start_date].max
      last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, aggregated_heat_meters.amr_data.end_date)
      aggregated_heat_meters.heating_model(last_year)
    end
  end
end
