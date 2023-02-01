# frozen_string_literal: true

module Costs
  class EconomicTariffsChangeCaveatsService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def calculate; end
  end
end
