# frozen_string_literal: true

require 'spec_helper'

describe AlertLayerUpPowerdownNovember2023ElectricityComparison do
  let(:alert) do
    described_class.new(build(:target_school, start_date: Date.new(2022, 11, 1),
                                              end_date: Date.new(2023, 11, 30)))
  end

  describe '#calculate' do
    it 'period_kwh' do
      alert.analyse(Date.new(2023, 11, 30))
      expect(alert.previous_period_kwh).to be_within(0.01).of(45.6)
      expect(alert.current_period_kwh).to be_within(0.01).of(45.6)
    end
  end
end
