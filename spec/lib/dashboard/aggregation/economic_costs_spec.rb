require 'spec_helper'

describe EconomicCosts do

  let(:start_date)  { Date.new(2023,1,1) }
  let(:end_date)    { Date.new(2023,1,31) }

  let(:rates)       { create_flat_rate(rate: 0.15, standing_charge: 1.0) }

  let(:accounting_tariff) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date, rates: rates) }

  let(:meter_attributes) {
    {:accounting_tariff_generic=> [accounting_tariff]}
  }

  let(:kwh_data_x48)       { Array.new(48, 0.01) }

  let(:combined_meter)      { build(:meter) }
  let(:meter_1) { build(:meter,
      type: :electricity,
      meter_attributes: meter_attributes,
      amr_data: build(:amr_data, :with_days, day_count: 31, end_date: end_date, kwh_data_x48: kwh_data_x48)
    )
  }

  let(:meter_2) { build(:meter,
      type: :electricity,
      meter_attributes: meter_attributes,
      amr_data: build(:amr_data, :with_days, day_count: 31, end_date: end_date, kwh_data_x48: kwh_data_x48)
    )
  }

  let(:list_of_meters)      { [meter_1, meter_2] }

  let(:combined_start_date) { start_date }
  let(:combined_end_date)   { end_date }

  #Simulate the meters having been through aggregation
  before(:each) do
    list_of_meters.each do |m|
      m.amr_data.set_tariffs(m)
    end
  end

  #test using new generic tariff manager
  around do |example|
    ClimateControl.modify FEATURE_FLAG_USE_NEW_ENERGY_TARIFFS: 'true' do
      example.run
    end
  end

  context '#combine_economic_costs_from_multiple_meters' do
    let(:combined_costs)  { EconomicCosts.combine_economic_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date, combined_end_date) }

    #usage * rate * 48 hh periods * 2 meters
    let(:expected_total_cost) { (0.01 * 0.15) * 48 * 2 }

    it 'has expected type' do
      expect(combined_costs).to be_a EconomicCostsPrecalculated
    end

    it 'has expected numbers of days' do
      expect(combined_costs.date_range).to eq(start_date..end_date)
    end

    it 'has expected bill_component_types' do
      #no standing charge as this is economic costs
      expect(combined_costs.bill_component_types).to match_array(['flat_rate'])
    end

    it 'has expected cost for start date' do
      expect(combined_costs.one_day_total_cost(start_date).round(3)).to eq expected_total_cost.round(3)
    end

    it 'has expected cost for end date' do
      expect(combined_costs.one_day_total_cost(end_date).round(3)).to eq expected_total_cost.round(3)
    end

  end

  context '#combine_current_economic_costs_from_multiple_meters' do
    let(:accounting_tariff) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date - 1, rates: rates) }

    let(:current_rates) { create_flat_rate(rate: 1.5)}

    let(:current_accounting_tariff) { create_accounting_tariff_generic(start_date: end_date, end_date: end_date, rates: current_rates) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [accounting_tariff, current_accounting_tariff]}
    }

    let(:combined_costs)  { EconomicCosts.combine_current_economic_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date, combined_end_date) }

    #usage * rate * 48 hh periods * 2 meters
    let(:expected_total_cost) { (0.01 * 1.5) * 48 * 2 }

    it 'has expected type' do
      expect(combined_costs).to be_a CurrentEconomicCostsPrecalculated
    end

    it 'has expected numbers of days' do
      expect(combined_costs.date_range).to eq(start_date..end_date)
    end

    it 'has expected bill_component_types' do
      #no standing charge as this is economic costs
      expect(combined_costs.bill_component_types).to match_array(['flat_rate'])
    end

    #should be using cost for latest tariff, not earliest
    it 'has expected cost for start date' do
      expect(combined_costs.one_day_total_cost(start_date).round(3)).to eq expected_total_cost.round(3)
    end

    it 'has expected cost for end date' do
      expect(combined_costs.one_day_total_cost(end_date).round(3)).to eq expected_total_cost.round(3)
    end
  end
end