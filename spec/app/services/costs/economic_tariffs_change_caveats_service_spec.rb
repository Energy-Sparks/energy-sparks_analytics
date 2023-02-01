# frozen_string_literal: true

require 'spec_helper'
describe Costs::EconomicTariffsChangeCaveatsService do
  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#calculate' do
    it 'determines if there is enough data' do
      service = Costs::EconomicTariffsChangeCaveatsService.new(meter_collection: @acme_academy)
      expect(service.calculate).to eq(nil)
    end
  end
end
