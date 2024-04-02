# frozen_string_literal: true

require 'spec_helper'

describe AlertLayerUpPowerdownNovember2023GasComparison do
  let(:alert) do
    start_date = Date.new(2021, 11, 30)
    end_date = Date.new(2023, 11, 30)
    meter_collection = build(
      :meter_collection, :with_aggregate_meter,
      start_date: start_date, end_date: end_date, fuel_type: :gas,
      pseudo_meter_attributes: { aggregated_gas: { targeting_and_tracking: [{ start_date: start_date, target: 1 }] } }
    )
    meter = build(:meter, :with_flat_rate_tariffs,
                  meter_collection: meter_collection, type: :gas,
                  amr_data: build(:amr_data, :with_date_range,
                                  type: :gas, start_date: start_date, end_date: end_date,
                                  kwh_data_x48: Array.new(48, 1)))
    meter_collection.add_heat_meter(meter)
    AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters
    described_class.new(meter_collection)
  end

  describe '#calculate' do
    it 'period_kwh' do
      allow_any_instance_of(AnalyseHeatingAndHotWater::HeatingNonHeatingRegressionModelBase).to( # rubocop:todo RSpec/AnyInstance
        receive(:max_non_heating_day_kwh).and_return(1)
      )
      alert.analyse(Date.new(2023, 11, 30))
      expect(alert.previous_period_kwh).to be_within(0.01).of(48)
      expect(alert.current_period_kwh).to be_within(0.01).of(48)
    end
  end
end
