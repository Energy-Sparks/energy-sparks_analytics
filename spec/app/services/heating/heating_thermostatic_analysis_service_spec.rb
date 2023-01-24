# frozen_string_literal: true

require 'spec_helper'

describe Heating::HeatingThermostaticAnalysisService do
  let(:service) { Heating::HeatingThermostaticAnalysisService.new(aggregated_heat_meters: @acme_academy.aggregated_heat_meters) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis' do
      model = service.create_model
      expect(model.r2).to eq(0.7329578423502179)
    end
  end
end
