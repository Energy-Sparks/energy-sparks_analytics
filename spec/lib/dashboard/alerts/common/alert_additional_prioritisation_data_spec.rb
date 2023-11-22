# frozen_string_literal: true

require 'spec_helper'

describe AlertAdditionalPrioritisationData do
  let(:fuel_type) { :electricity }

  let(:amr_start_date)  { Date.new(2021, 12, 31) }
  let(:amr_end_date)    { Date.new(2022, 12, 31) }
  let(:amr_data) { build(:amr_data, :with_date_range, start_date: amr_start_date, end_date: amr_end_date) }

  # Tariffs used to calculate costs
  let(:rates) { create_flat_rate(rate: 0.10, standing_charge: 1.0) }
  let(:accounting_tariff) { create_accounting_tariff_generic(start_date: amr_start_date, end_date: amr_end_date, rates: rates) }
  let(:meter_attributes) do
    { accounting_tariff_generic: [accounting_tariff] }
  end

  # Meter to use as the aggregates
  let(:meter) { build(:meter, type: fuel_type, meter_attributes: meter_attributes, amr_data: amr_data) }

  let(:meter_collection) { build(:meter_collection) }

  let(:asof_date)        { Date.new(2022, 12, 31) }
  let(:alert)            { AlertAdditionalPrioritisationData.new(meter_collection) }

  before do
    allow(meter_collection).to receive(:aggregated_electricity_meters).and_return(meter)
    allow(meter_collection).to receive(:aggregated_heat_meters).and_return(meter)
    # TODO: this is not yet in factory because of circular dependency, need to
    # refactor meter/amr_data/aggregation_mixin
    amr_data.set_tariffs(meter)
  end

  describe '#benchmark_template_data' do
    before do
      alert.analyse(asof_date)
    end

    let(:template_data) { alert.benchmark_template_data }

    it 'assigns the correct values' do
      expect(template_data[:addp_name]).to eq meter_collection.school.name
      expect(template_data[:addp_pupn]).to eq meter_collection.school.number_of_pupils
      expect(template_data[:addp_flra]).to eq meter_collection.school.floor_area
      expect(template_data[:addp_sctp]).to eq meter_collection.school.school_type
      expect(template_data[:addp_urn]).to eq meter_collection.school.urn
      expect(template_data[:addp_sact]).to eq meter_collection.school.activation_date
      expect(template_data[:addp_sact]).to eq meter_collection.energysparks_start_date
    end
  end
end
