# frozen_string_literal: true

module Heating
  class HeatingThermostaticAnalysisService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
      OpenStruct.new(
        r2: r2
      )
    end

    private

    def calculate_heating_model
      start_date = [aggregated_heat_meters.amr_data.end_date - 364, aggregated_heat_meters.amr_data.start_date].max
      last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, aggregated_heat_meters.amr_data.end_date)
      aggregated_heat_meters.heating_model(last_year, :simple_regression_temperature)
    end

    def heating_model
      @heating_model ||= calculate_heating_model
    end

    def r2
      heating_model.average_heating_school_day_r2
    end
  end
end
