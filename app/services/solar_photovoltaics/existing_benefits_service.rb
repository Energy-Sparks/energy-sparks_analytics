# frozen_string_literal: true

module SolarPhotovoltaics
  class ExistingBenefitsService
    def initialize(meter_collection:)
      @meter_collection = meter_collection

      raise unless @meter_collection.solar_pv_panels?
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Layout/LineLength
    def create_model
      OpenStruct.new(
        annual_saving_from_solar_pv_percent: solar_pv_profit_loss.annual_saving_from_solar_pv_percent,
        annual_carbon_saving_percent: solar_pv_profit_loss.annual_carbon_saving_percent,
        annual_electricity_including_onsite_solar_pv_consumption_kwh: solar_pv_profit_loss.annual_electricity_including_onsite_solar_pv_consumption_kwh,
        annual_consumed_from_national_grid_kwh: solar_pv_profit_loss.annual_consumed_from_national_grid_kwh,
        saving_£current: saving_£current,
        export_£: export_£,
        annual_co2_saving_kg: solar_pv_profit_loss.annual_co2_saving_kg,
        annual_solar_pv_kwh: solar_pv_profit_loss.annual_solar_pv_kwh,
        annual_exported_solar_pv_kwh: solar_pv_profit_loss.annual_exported_solar_pv_kwh,
        annual_solar_pv_consumed_onsite_kwh: solar_pv_profit_loss.annual_solar_pv_consumed_onsite_kwh
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Layout/LineLength

    private

    # rubocop:disable Naming/MethodName
    def export_£
      solar_pv_profit_loss.annual_exported_solar_pv_kwh * BenchmarkMetrics::SOLAR_EXPORT_PRICE
    end

    def saving_£current
      solar_pv_profit_loss.annual_solar_pv_consumed_onsite_kwh * electricity_price_£current_per_kwh
    end

    def electricity_price_£current_per_kwh
      @meter_collection.aggregated_electricity_meters.amr_data.blended_rate(:kwh, :£current).round(5)
    end
    # rubocop:enable Naming/MethodName

    def solar_pv_profit_loss
      @solar_pv_profit_loss = SolarPVProfitLoss.new(@meter_collection)
    end
  end
end
