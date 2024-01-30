# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/integer'
require 'spec_helper'

describe Usage::PeakUsageCalculationService, type: :service do
  subject(:service) { described_class.new(meter_collection: meter_collection, asof_date: asof_date) }

  let(:meter_collection) do
    amr_data = build(:amr_data, :with_date_range, start_date: start_date, kwh_data_x48: [0.5] * 48)
    collection = build(:meter_collection, start_date: start_date)
    meter = build(:meter, meter_collection: collection, type: :electricity, amr_data: amr_data)
    collection.set_aggregate_meter(:electricity, meter)
    collection
  end
  let(:asof_date) { Date.new(2022, 1, 1) }
  let(:start_date) { asof_date - 59.days }

  describe '#enough_data?' do
    it { is_expected.to be_enough_data }

    context 'with not enough data' do
      let(:start_date) { asof_date - 58.day }

      it { is_expected.not_to be_enough_data }
    end
  end

  describe '#determines when data is available' do
    it 'returns the date that meter data is available from' do
      # returns nil as days_of_data >= days_required
      expect(service.data_available_from).to eq(nil)
    end
  end

  describe '#average_school_day_peak_usage_kw' do
    it 'calculates the average school day peak usage in kw from a given asof date' do
      expect(service.average_peak_kw.to_s).to eq('1.0')
    end
  end
end
