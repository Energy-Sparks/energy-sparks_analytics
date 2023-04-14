require 'spec_helper'

module Logging
  logger.level = :debug
end

describe ValidateAMRData, type: :service do

  let(:meter_collection)          { @acme_academy }
  let(:meter)                     { meter_collection.electricity_meters.first }
  let(:max_days_missing_data)     { 50 }

  context 'with real data' do
    #using before(:all) here to avoid slow loading of YAML
    before(:all) do
      @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy', validate_and_aggregate: false)
    end
    let(:validator) { ValidateAMRData.new(meter, max_days_missing_data, meter_collection.holidays, meter_collection.temperatures) }

    it 'validates' do
      validator.validate(debug_analysis: true)
      expect(validator.data_problems).to be_empty
    end
  end
end
