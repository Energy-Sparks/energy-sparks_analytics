# frozen_string_literal: true

require 'spec_helper'

describe AccountingCosts do
  let(:start_date)  { Date.new(2023, 1, 1) }
  let(:end_date)    { Date.new(2023, 1, 31) }

  let(:rates)       { create_flat_rate(rate: 0.15, standing_charge: 1.0) }

  let(:accounting_tariff) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date, rates: rates) }

  let(:meter_attributes) do
    { accounting_tariff_generic: [accounting_tariff] }
  end

  let(:kwh_data_x48) { Array.new(48, 0.01) }

  let(:combined_meter) { build(:meter) }
  let(:meter_1) do
    build(:meter,
          type: :electricity,
          meter_attributes: meter_attributes,
          amr_data: build(:amr_data, :with_days, day_count: 31, end_date: end_date,
                                                 kwh_data_x48: kwh_data_x48))
  end

  let(:meter_2) do
    build(:meter,
          type: :electricity,
          meter_attributes: meter_attributes,
          amr_data: build(:amr_data, :with_days, day_count: 31, end_date: end_date,
                                                 kwh_data_x48: kwh_data_x48))
  end

  let(:list_of_meters)      { [meter_1, meter_2] }

  let(:combined_start_date) { start_date }
  let(:combined_end_date)   { end_date }

  # Simulate the meters having been through aggregation
  before do
    list_of_meters.each do |m|
      m.amr_data.set_tariffs(m)
    end
  end

  describe '#combine_accounting_costs_from_multiple_meters' do
    let(:combined_costs) do
      described_class.combine_accounting_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date,
                                                                    combined_end_date)
    end

    # usage * rate * 48 hh periods * 2 meters + 2 * 1.0
    let(:expected_total_cost) { (0.01 * 0.15 * 48 * 2) + 2.0 }

    it 'has expected type' do
      expect(combined_costs).to be_a AccountingCostsPrecalculated
    end

    it 'has expected numbers of days' do
      expect(combined_costs.date_range).to eq(start_date..end_date)
      expect(combined_costs.date_missing?(start_date)).to eq false
      expect(combined_costs.date_missing?(end_date)).to eq false
    end

    it 'has expected bill_component_types' do
      expect(combined_costs.bill_component_types).to match_array(['flat_rate', :standing_charge])
    end

    it 'has expected cost for start date' do
      expect(combined_costs.one_day_total_cost(start_date).round(3)).to eq expected_total_cost.round(3)
    end

    it 'has expected cost for end date' do
      expect(combined_costs.one_day_total_cost(end_date).round(3)).to eq expected_total_cost.round(3)
    end

    context 'with missing tariffs' do
      before do
        allow(meter_1.amr_data).to receive(:date_exists_by_type?).and_return(false)
      end

      it 'has expected type' do
        expect(combined_costs).to be_a AccountingCostsPrecalculated
      end

      it 'has skipped the calculation' do
        expect(combined_costs.date_missing?(start_date)).to eq true
        expect(combined_costs.date_missing?(end_date)).to eq true
      end
    end
  end
end
