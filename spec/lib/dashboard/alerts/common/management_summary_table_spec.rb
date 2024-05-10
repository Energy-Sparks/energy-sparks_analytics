# frozen_string_literal: true

require 'spec_helper'
require 'dashboard'

describe ManagementSummaryTable do
  subject(:alert) do
    described_class.new(meter_collection)
  end

  let(:start_date) { Date.new(2022, 11, 1) }
  let(:today) { Date.new(2023, 11, 30) }
  let(:meter_collection) do
    build(:meter_collection, :with_fuel_and_aggregate_meters,
          start_date: start_date, end_date: today)
  end

  describe '#reporting_period' do
    it 'returns expected period' do
      expect(alert.reporting_period).to eq(:last_12_months)
    end
  end

  describe '#analyse' do
    let(:result) do
      alert.analyse(today)
    end
    let(:variables) do
      alert.variables_for_reporting
    end

    it 'runs the calculation and produces expected variables' do
      expect(result).to be true
      expect(variables.dig(:summary_data, :electricity)).not_to be_nil
      electricity_data = variables.dig(:summary_data, :electricity)
      expect(electricity_data[:start_date]).to eq(start_date)
      expect(electricity_data[:end_date]).to eq(today)

      expect(electricity_data.dig(:year, :recent)).to be true
      expect(electricity_data.dig(:workweek, :recent)).to be true

      # Notes on kwh, co2, £ calculations
      # By default the meter collection factory creates meter with data that has
      # 48 kWh per day, tariffs of 0.1 per kWh, co2 of rand(0.2..0.3).round(3)
      expect(electricity_data.dig(:workweek, :kwh)).to eq(336.0)
      expect(electricity_data.dig(:workweek, :£)).to be_within(0.0001).of(33.6)
      expect(electricity_data.dig(:workweek, :co2)).to be > 0

      expect(electricity_data.dig(:year, :kwh)).to eq(17_472.0)
      expect(electricity_data.dig(:year, :£)).to be_within(0.0001).of(1747.20)
      expect(electricity_data.dig(:year, :co2)).to be > 0

      expect(variables.dig(:summary_data, :gas)).to be_nil
      expect(variables.dig(:summary_data, :storage_heaters)).to be_nil
    end

    context 'with gas' do
      let(:meter_collection) do
        build(:meter_collection, :with_fuel_and_aggregate_meters,
              start_date: start_date, end_date: today, fuel_type: :gas)
      end

      it 'runs the calculation and produces expected variables' do
        expect(result).to be true
        expect(variables.dig(:summary_data, :gas)).not_to be_nil
        expect(variables.dig(:summary_data, :electricity)).to be_nil
        expect(variables.dig(:summary_data, :storage_heaters)).to be_nil
      end
    end

    context 'with storage heaters' do
      let(:meter_collection) do
        build(:meter_collection, :with_fuel_and_aggregate_meters,
              start_date: start_date, end_date: today, storage_heaters: true)
      end

      it 'runs the calculation and produces expected variables' do
        expect(result).to be true
        expect(variables.dig(:summary_data, :gas)).to be_nil
        expect(variables.dig(:summary_data, :electricity)).not_to be_nil
        expect(variables.dig(:summary_data, :storage_heaters)).not_to be_nil
      end
    end
  end
end
