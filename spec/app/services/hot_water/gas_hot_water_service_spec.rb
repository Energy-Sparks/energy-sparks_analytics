# frozen_string_literal: true

require 'spec_helper'

describe HotWater::GasHotWaterService do
  let(:service) { HotWater::GasHotWaterService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis' do
      model = service.create_model
      puts model.inspect
      expect(model.investment_data).to eq({})
    end
  end
end
