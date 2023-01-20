# frozen_string_literal: true

module Heating
  class HeatingThermostaticAnalysisService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
    end
  end
end
