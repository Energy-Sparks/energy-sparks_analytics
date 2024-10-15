# frozen_string_literal: true

require 'spec_helper'

# module Logging
#  logger.level = :debug
# end

describe ValidateAMRData, type: :service do
  let(:meter_collection)          { @acme_academy }
  let(:meter)                     { meter_collection.meter?(1_591_058_886_735) }
  let(:max_days_missing_data)     { 50 }

  context 'with real data' do
    # using before(:all) here to avoid slow loading of YAML
    before(:all) do
      @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy', validate_and_aggregate: false)
    end

    let(:validator) do
      described_class.new(meter, max_days_missing_data, meter_collection.holidays, meter_collection.temperatures)
    end

    it 'validates' do
      validator.validate(debug_analysis: true)
      expect(validator.data_problems).to be_empty
    end
  end

  context 'with factory' do
    let(:meter_collection) { build(:meter_collection, :with_electricity_meter) }
    let(:meter) { meter_collection.electricity_meters.first }
    let(:validator) do
      described_class.new(meter, max_days_missing_data, meter_collection.holidays, meter_collection.temperatures)
    end

    it 'replaces missing night time solar readings with 0' do
      missing_date = meter.amr_data.keys.sort[1]
      meter.amr_data.delete(missing_date)
      meter.instance_variable_set(:@meter_type, :solar_pv)
      validator.validate(debug_analysis: true)
      expect(validator.data_problems).to be_empty
      expect(meter.amr_data[missing_date].kwh_data_x48).to include(0.0)
    end
  end
end
