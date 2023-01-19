# frozen_string_literal: true

module SolarPhotovoltaics
  class ExistingBenefitsService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def calculate
      OpenStruct.new(
        annual_saving_from_solar_pv_percent: solar_pv_profit_loss.annual_saving_from_solar_pv_percent
      )
    end

    private

    def solar_pv_profit_loss
      @solar_pv_profit_loss = SolarPVProfitLoss.new(@meter_collection)
    end
  end
end
