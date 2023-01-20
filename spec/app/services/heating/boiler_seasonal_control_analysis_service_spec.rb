require 'spec_helper'

describe Heating::BoilerSeasonalControlAnalysisService do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:factory)        { Heating::BoilerSeasonalControlAnalysisService.new(aggregate_meter: @acme_academy.aggregated_heat_meters)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it '' do
    end
  end
end
