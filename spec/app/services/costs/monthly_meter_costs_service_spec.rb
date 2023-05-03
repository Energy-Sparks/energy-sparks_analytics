# frozen_string_literal: true
require 'spec_helper'
describe Costs::MonthlyMeterCostsService, type: :service do
  let(:meter)   { @acme_academy.electricity_meters.first } # 1591058886735
  let(:service) { Costs::MonthlyMeterCostsService.new(meter: meter) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    it 'determines if there is enough data' do
      expect(service.enough_data?).to eq(true)
    end
  end

  context '#calculate_costs_for_month' do
    let(:costs)  { service.calculate_costs_for_month(month: month) }

    context 'with date before earliest data' do
      let(:month)  { Date.new(2018,11,1) }
      it 'returns nil' do
        expect(costs).to be_nil
      end
    end
    context 'with data after latest data' do
      let(:month)  { Date.new(2022,11,1) }
      it 'returns nil' do
        expect(costs).to be_nil
      end
    end
    context 'with partial first month' do
      let(:month)  { Date.new(2019,1,1) }
      it 'returns expected costs' do
        expect(costs.month_start_date).to eq(month)
        expect(costs.start_date).to eq(Date.parse('2019-01-13'))
        expect(costs.end_date).to eq(Date.parse('2019-01-31'))
        expect(costs.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
        expect(costs.bill_component_costs[:flat_rate]).to round_to_two_digits(1554.26) # 1554.2571449999998
        expect(costs.bill_component_costs[:standing_charge]).to round_to_two_digits(19.0) # 19.0
        expect(costs.full_month).to eq(false)
        expect(costs.total).to eq(costs.bill_component_costs[:flat_rate] + costs.bill_component_costs[:standing_charge])
      end
    end
    context 'with whole month' do
      let(:month) { Date.new(2021,7,1) }

      it 'returns expected results' do
        expect(costs.month_start_date).to eq(month)
        expect(costs.start_date).to eq(month)
        expect(costs.end_date).to eq(Date.new(2021,7,31))
        expect(costs.days).to eq(31)
        expect(costs.full_month).to eq(true)
        expect(costs.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
        expect(costs.bill_component_costs[:flat_rate]).to round_to_two_digits(715.35) # 715.35
        expect(costs.bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
        expect(costs.total).to round_to_two_digits(746.35) # 746.35
      end
    end
    context 'with partial final month' do
      let(:month)  { Date.new(2022, 7, 1) }
      it 'returns expected costs' do
        expect(costs.month_start_date).to eq(month)
        expect(costs.start_date).to eq(month)
        expect(costs.end_date).to eq(Date.new(2022,7,13))
        expect(costs.days).to eq(13)
        expect(costs.full_month).to eq(false)
        expect(costs.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
        expect(costs.bill_component_costs[:flat_rate]).to round_to_two_digits(394.83) # 394.83000000000004
        expect(costs.bill_component_costs[:standing_charge]).to round_to_two_digits(13.0) # 13.0
        expect(costs.total).to round_to_two_digits(407.83) # 407.83000000000004
      end
    end
  end

  context '#calculate_costs_for_months' do
    let(:before) { Date.new(2018,11,1) }
    let(:after)  { Date.new(2022,11,1) }
    let(:first_month) { Date.new(2019,1,1) }
    let(:months) { [before, after, first_month] }
    let(:monthly_billing) { service.calculate_costs_for_months(months: months)}

    it 'returns expected results' do
      expect( monthly_billing[before] ).to be_nil
      expect( monthly_billing[after] ).to be_nil
      expect( monthly_billing[first_month].total).to round_to_two_digits(1573.26)
    end
  end

  context '#calculate_costs_for_latest_twelve_months' do
    let(:monthly_costs)  { service.calculate_costs_for_latest_twelve_months }
    it 'returns expected data' do
      expect(monthly_costs.keys.length).to eq 13
      expect(monthly_costs[Date.new(2022,7,1)]).to_not be_nil
      expect(monthly_costs[Date.new(2021,7,1)]).to_not be_nil
    end
  end

  context '#calculate_costs_for_previous_twelve_months' do
    let(:monthly_costs)  { service.calculate_costs_for_previous_twelve_months }
    it 'returns expected data' do
      expect(monthly_costs.keys.length).to eq 13
      expect(monthly_costs[Date.new(2021,7,1)]).to_not be_nil
      expect(monthly_costs[Date.new(2020,7,1)]).to_not be_nil
    end
  end

end
