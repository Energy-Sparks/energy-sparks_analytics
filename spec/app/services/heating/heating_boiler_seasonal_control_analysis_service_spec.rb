require 'spec_helper'

describe Heating::HeatingBoilerSeasonalControlAnalysisService do

  let(:service)        { Heating::HeatingBoilerSeasonalControlAnalysisService.new(aggregated_heat_meters: @acme_academy.aggregated_heat_meters)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'it creates model for results of a boiler seasonal control analysis' do
      model = service.create_model
      expect(model.number_days_heating_on_in_warm_weather).to eq(18.0)
      
    end
  end
end
