module Heating
  class BoilerSeasonalControlAnalysisService < BaseService
    def initialize(aggregate_meter:)
      @aggregate_meter = aggregate_meter
    end
  end
end