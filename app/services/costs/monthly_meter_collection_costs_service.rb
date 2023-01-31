# frozen_string_literal: true

module Costs
  class MonthlyMeterCollectionCostsService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def calculate_costs
      meter_collection_costs = []
      @meter_collection.electricity_meters.each do |meter|
        meter_collection_costs << OpenStruct.new(
          mpan_mprn: meter.mpan_mprn,
          meter_name: meter.name,
          meter_monthly_costs_breakdown: Costs::MonthlyMeterCostsService.new(meter: meter).calculate_costs
        )
      end
      meter_collection_costs
    end
  end
end
