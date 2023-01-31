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
      expect(model.kwh).to round_to_two_digits(19_909.44) # 19_909.43570393906
      expect(model.£).to round_to_two_digits(597.28) # 597.2830711181718
      expect(model.£current).to round_to_two_digits(597.28) # 597.2830711181718
      expect(model.co2).to round_to_two_digits(4180.98) # 4180.9814978272025
      expect(model.days).to round_to_two_digits(18.0) # 18.0
      expect(model.degree_days).to round_to_two_digits(56.09) # 56.088333333333345
    end
  end
end
