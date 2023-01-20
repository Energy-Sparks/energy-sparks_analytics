# frozen_string_literal: true

require 'spec_helper'

describe Heating::HeatingBoilerSeasonalControlAnalysisService do
  let(:service) { Heating::HeatingBoilerSeasonalControlAnalysisService.new(aggregated_heat_meters: @acme_academy.aggregated_heat_meters) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'it creates model for results of a boiler seasonal control analysis' do
      model = service.create_model
      expect(model.kwh).to eq(19_909.43570393906)
      expect(model.£).to eq(597.2830711181718)
      expect(model.£current).to eq(597.2830711181718)
      expect(model.co2).to eq(4180.9814978272025)
      expect(model.days).to eq(18.0)
      expect(model.degree_days).to eq(56.088333333333345)
    end
  end
end
