# frozen_string_literal: true

require 'spec_helper'

# module Logging
#  logger.level = :debug
# end

describe ValidateAMRData, type: :service do
  subject(:validator) do
    described_class.new(meter, max_days_missing_data, meter_collection.holidays, meter_collection.temperatures)
  end

  let(:meter_collection) { build(:meter_collection, :with_electricity_meter, random_generator: Random.new(17)) }
  let(:meter) { meter_collection.electricity_meters.first }
  let(:max_days_missing_data) { 50 }

  context 'with real data' do
    let(:meter_collection) { @acme_academy }
    let(:meter) { meter_collection.meter?(1_591_058_886_735) }

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

  it 'replaces missing night time solar readings with 0' do
    missing_date = meter.amr_data.keys.sort[1]
    meter.amr_data.delete(missing_date)
    meter.instance_variable_set(:@meter_type, :solar_pv)
    validator.validate(debug_analysis: true)
    expect(validator.data_problems).to be_empty
    expect(meter.amr_data[missing_date].kwh_data_x48).to include(0.0)
  end

  context 'with override_night_to_zero' do
    it 'replace night time readings with a rule' do
      meter.meter_correction_rules << { override_night_to_zero: {} }
      validator.validate(debug_analysis: true)
      expect(arbitrary_night_readings(meter)).to eq(Array.new(8, 0.0))
    end

    it 'replace night time readings with a rule with dates' do
      meter.meter_correction_rules << { override_night_to_zero: { start_date: meter.amr_data.start_date + 1.day,
                                                                  end_date: meter.amr_data.start_date + 2.days } }
      validator.validate(debug_analysis: true)
      expect(arbitrary_night_readings(meter)).to eq([0.44, 0.0, 0.0, 0.44, 0.44, 0.44, 0.44, 0.44])
    end
  end

  def arbitrary_night_readings(meter)
    meter.amr_data.to_a.sort.map { |data| data[1].kwh_data_x48[5] }
  end
end
