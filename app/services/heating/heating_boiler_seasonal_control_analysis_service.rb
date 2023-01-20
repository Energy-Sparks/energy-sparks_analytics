# frozen_string_literal: true

module Heating
  class HeatingBoilerSeasonalControlAnalysisService < BaseService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
      OpenStruct.new(
        number_days_heating_on_in_warm_weather: number_days_heating_on_in_warm_weather
      )
    end

    private

    def number_days_heating_on_in_warm_weather
      aggregate_analysis(:heating_warm_weather, :days)
    end

    def aggregate_analysis(heating_type, value_type)
      seasonal_analysis.values.map do |by_heating_regime_data|
        by_heating_regime_data.dig(heating_type, value_type)
      end.compact.sum
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
