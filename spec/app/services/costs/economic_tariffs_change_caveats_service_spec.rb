# frozen_string_literal: true

require 'spec_helper'
describe Costs::EconomicTariffsChangeCaveatsService do
  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @beta_academy = load_unvalidated_meter_collection(school: 'beta-academy')
  end

  context '#calculate_economic_tariff_changed' do
    it 'calulates economic tariff changed data' do
      service = Costs::EconomicTariffsChangeCaveatsService.new(meter_collection: @beta_academy, fuel_type: :electricity)
      model = service.calculate_economic_tariff_changed

      expect(model.last_change_date).to eq(Date.new(2023, 4, 1))
      expect(model.percent_change).to be_within(0.01).of(0.88)
      expect(model.rate_after_£_per_kwh).to be_within(0.01).of(0.21)
      expect(model.rate_before_£_per_kwh).to be_within(0.01).of(0.11)
    end
  end
end
