# frozen_string_literal: true

require 'spec_helper'

describe AlertHolidayAndTermElectricityComparison do
  let(:holidays)         { build(:holidays, :with_calendar_year, year: 2023) }
  let(:meter_collection) do
    build(:meter_collection, :with_fuel_and_aggregate_meters,
          holidays: holidays, start_date: Date.new(2023, 1, 1), end_date: Date.new(2023, 12, 31))
  end

  subject(:alert) { described_class.new(meter_collection) }

  describe '#current_period_name' do
    context 'when running after a holiday has ended' do
      it 'returns last holiday name'
    end

    context 'when running during a holiday' do
      it 'returns current holiday name'
    end
  end

  describe '#previous_period_name' do
    context 'when running after a holiday has ended' do
      it 'returns correct name'
    end

    context 'when running during a holiday' do
      it 'returns current name'
    end
  end

  describe '#analyse' do
    before do
      alert.analyse(analysis_date)
    end

    context 'when running after a holiday has ended' do
      let(:analysis_date) { Date.new(2023, 9, 1) }

      it 'calculates variables' do
        expect(alert.valid_alert?).to be true
        expect(alert.analysis_date).to eq(analysis_date)
        expect(alert.current_period_kwh).to be_within(0.01).of(48)
      end
    end

    context 'when running during a holiday' do
      context 'with not enough data' do
        it 'does not run'
      end

      context 'with enough days of data' do
        let(:analysis_date) { Date.new(2023, 8, 1) }

        it 'calculates variables' do
          expect(alert.valid_alert?).to be true
          expect(alert.analysis_date).to eq(analysis_date)
          expect(alert.current_period_kwh).to be_within(0.01).of(48)
        end
      end
    end
  end
end
