# frozen_string_literal: true

module Costs
  class MonthlyMeterCollectionCostsService
    def initialize(meter_collection:, fuel_type:)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
    end

    def calculate_costs
      meter_collection_costs = []
      meters.each do |meter|
        meter_collection_costs << OpenStruct.new(
          mpan_mprn: meter.mpan_mprn,
          meter_name: meter.name,
          meter_monthly_costs_breakdown: Costs::MonthlyMeterCostsService.new(meter: meter).calculate_costs
        )
      end
      meter_collection_costs
    end

    private

    def meters
      @meters ||= case @fuel_type
                  when :electricity then @meter_collection.electricity_meters
                  when :gas then @meter_collection.heat_meters
                  end
    end
  end
end
