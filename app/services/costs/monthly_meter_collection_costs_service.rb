module Costs
  class MonthlyMeterCollectionCostsService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def create_model
      meter_collection_costs = []
      @meter_collection.electricity_meters.each do |meter|
        meter_collection_costs << OpenStruct.new(
          mpan_mprn: meter.mpan_mprn,
          meter_name: meter.name,
          meter_monthly_costs_breakdown: Costs::MonthlyMeterCostsService.new(meter: meter).create_model
        )
      end
      meter_collection_costs
    end
  end
end
