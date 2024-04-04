# frozen_string_literal: true

require 'spec_helper'

describe AlertConfigurablePeriodGasComparison do
  let(:alert) do
    meter_collection = build(:meter_collection, :with_fuel_and_aggregate_meters,
                             fuel_type: :gas, start_date: Date.new(2022, 11, 1), end_date: Date.new(2023, 11, 30))
    AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters
    described_class.new(meter_collection)
  end

  describe '#analyse' do
    it 'period_kwh' do
      configuration = {
        name: 'Layer up power down day 24 November 2023',
        max_days_out_of_date: 365,
        enough_days_data: 1,
        current_period: Date.new(2023, 11, 24)..Date.new(2023, 11, 24),
        previous_period: Date.new(2023, 11, 17)..Date.new(2023, 11, 17)
      }
      alert.analyse(Date.new(2023, 11, 30), comparison_configuration: configuration)
      expect(alert.previous_period_kwh).to be_within(0.01).of(48)
      expect(alert.current_period_kwh).to be_within(0.01).of(48)
    end
  end
end
