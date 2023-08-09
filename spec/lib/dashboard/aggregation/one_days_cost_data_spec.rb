require 'spec_helper'

describe OneDaysCostData do

  context '#combine_costs' do
    let(:costs)     { build_list(:one_days_cost, 5) }
    let(:combined)  { OneDaysCostData.combine_costs(costs) }
    it 'combines rates' do
      expect(combined.all_costs_x48['flat_rate']).to eq AMRData.fast_add_multiple_x48_x_x48(costs.map {|c| c.all_costs_x48['flat_rate']})
    end
    it 'combines standing charges' do
      expect(combined.total_standing_charge).to eq 5.0
    end
  end

  context '.bill_components' do
    let(:one_days_cost) { build(:one_days_cost) }
    let(:bill_components) { one_days_cost.bill_components }
    it 'returns bill components' do
      expect(bill_components).to eq ['flat_rate', :standing_charge]
    end

    context 'with several components' do
      let(:rates_x48)     {
        {
          'flat_rate' => Array.new(48, 0.1),
          'Feed in tariff levy' => Array.new(48, 0.1),
          :climate_change_levy__2023_24 => Array.new(48, 0.1)
        }
      }
      let(:one_days_cost) { build(:one_days_cost, rates_x48: rates_x48) }

      it 'lists all of them' do
        expect(bill_components).to eq ['flat_rate', 'Feed in tariff levy', :climate_change_levy__2023_24, :standing_charge]
      end
    end
  end

  context '.bill_component_costs_per_day' do
    let(:rates_x48)     {
      {
        'flat_rate' => Array.new(48, 0.1),
        'Feed in tariff levy' => Array.new(48, 0.1)
      }
    }
    let(:one_days_cost) { build(:one_days_cost, rates_x48: rates_x48) }

    let(:costs) { one_days_cost.bill_component_costs_per_day }
    it 'returns costs' do
      expect(costs['flat_rate'].round(2)).to eq 4.80
      expect(costs['Feed in tariff levy'].round(2)).to eq 4.80
      expect(costs[:standing_charge].round(2)).to eq 1.0
    end
  end

end