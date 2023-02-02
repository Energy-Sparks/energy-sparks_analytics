# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Layout/LineLength, Metrics/BlockLength
describe Costs::MonthlyMeterCollectionCostsService do
  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    it 'determines if there is enough data' do
      service = Costs::MonthlyMeterCollectionCostsService.new(meter_collection: @acme_academy, fuel_type: :electricity)
      expect(service.enough_data?).to eq(true)
    end
  end

  # context '#data_available_from' do
  #   it 'determines when data is available from' do
  #     service = Costs::MonthlyMeterCollectionCostsService.new(meter_collection: @acme_academy, fuel_type: :electricity)
  #     expect(service.data_available_from).to eq('')
  #   end
  # end

  context '#calculate_costs' do
    it 'creates a model for results of a costs analysis for electricity' do
      service = Costs::MonthlyMeterCollectionCostsService.new(meter_collection: @acme_academy, fuel_type: :electricity)
      model = service.calculate_costs
      expect(model.map(&:mpan_mprn).sort).to eq([1_580_001_320_420, 1_591_058_886_735])
      expect(model.map(&:meter_name).sort).to eq(['New building', 'Old building?'])

      expect(model.first.mpan_mprn).to eq(1_591_058_886_735)
      expect(model.first.meter_name).to eq('Old building?')

      expect(model.first.meter_monthly_costs_breakdown.count).to eq(43)
      expect(model.first.meter_monthly_costs_breakdown.first.month_start_date).to eq(Date.parse('2019-01-01'))
      expect(model.first.meter_monthly_costs_breakdown.first.start_date).to eq(Date.parse('2019-01-13'))
      expect(model.first.meter_monthly_costs_breakdown.first.end_date).to eq(Date.parse('2019-01-31'))
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs[:flat_rate]).to round_to_two_digits(1554.26) # 1554.2571449999998
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs[:standing_charge]).to round_to_two_digits(19.0) # 19.0
      expect(model.first.meter_monthly_costs_breakdown.first.full_month).to eq(false)
      expect(model.first.meter_monthly_costs_breakdown.first.total).to round_to_two_digits(1573.26) # 1573.2571449999998

      expect(model.first.meter_monthly_costs_breakdown.last.month_start_date).to eq(Date.parse('2022-07-01'))
      expect(model.first.meter_monthly_costs_breakdown.last.start_date).to eq(Date.parse('2022-07-01'))
      expect(model.first.meter_monthly_costs_breakdown.last.end_date).to eq(Date.parse('2022-07-13'))
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs[:flat_rate]).to round_to_two_digits(394.83) # 394.83000000000004
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs[:standing_charge]).to round_to_two_digits(13.0) # 13.0
      expect(model.first.meter_monthly_costs_breakdown.last.full_month).to eq(false)
      expect(model.first.meter_monthly_costs_breakdown.last.total).to round_to_two_digits(407.83) # 407.83000000000004
    end

    it 'creates a model for results of a costs analysis for gas' do
      service = Costs::MonthlyMeterCollectionCostsService.new(meter_collection: @acme_academy, fuel_type: :gas)
      model = service.calculate_costs
      expect(model.map(&:mpan_mprn).sort).to eq([10_307_706, 10_308_203, 10_308_607, 9_335_373_908])
      expect(model.map(&:meter_name).sort).to eq(['Art Block?', 'Lodge', 'New building', 'Old building'])

      expect(model.first.mpan_mprn).to eq(10_308_607)
      expect(model.first.meter_name).to eq('Old building')

      expect(model.first.meter_monthly_costs_breakdown.count).to eq(47)

      expect(model.first.meter_monthly_costs_breakdown.first.month_start_date).to eq(Date.parse('2018-09-01'))
      expect(model.first.meter_monthly_costs_breakdown.first.start_date).to eq(Date.parse('2018-09-01'))
      expect(model.first.meter_monthly_costs_breakdown.first.end_date).to eq(Date.parse('2018-09-30'))
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs[:flat_rate]).to round_to_two_digits(611.75) # 611.74965
      expect(model.first.meter_monthly_costs_breakdown.first.bill_component_costs[:standing_charge]).to round_to_two_digits(120.0) # 120.0
      expect(model.first.meter_monthly_costs_breakdown.first.full_month).to eq(true)
      expect(model.first.meter_monthly_costs_breakdown.first.total).to round_to_two_digits(731.75) # 731.74965

      expect(model.first.meter_monthly_costs_breakdown.last.month_start_date).to eq(Date.parse('2022-07-01'))
      expect(model.first.meter_monthly_costs_breakdown.last.start_date).to eq(Date.parse('2022-07-01'))
      expect(model.first.meter_monthly_costs_breakdown.last.end_date).to eq(Date.parse('2022-07-12'))
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs[:flat_rate]).to round_to_two_digits(0) # 0
      expect(model.first.meter_monthly_costs_breakdown.last.bill_component_costs[:standing_charge]).to round_to_two_digits(48.0) # 48.0
      expect(model.first.meter_monthly_costs_breakdown.last.full_month).to eq(false)
      expect(model.first.meter_monthly_costs_breakdown.last.total).to round_to_two_digits(48.0) # 48.0
    end
  end
end
# rubocop:enable Layout/LineLength, Metrics/BlockLength
