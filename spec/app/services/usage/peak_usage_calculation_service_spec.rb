# frozen_string_literal: true

require 'spec_helper'

describe Usage::PeakUsageCalculationService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }
  let(:service) do
    Usage::PeakUsageCalculationService.new(
        meter_collection: meter_collection,
        asof_date: Date.new(2022, 1, 1)
    )
  end

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    it 'returns true if there is a years worth of data' do
      expect(service.enough_data?).to eq(true)
    end
  end

  context '#determines when data is available' do
    it 'returns the date that meter data is available from' do
      # returns nil as days_of_data >= days_required
      expect(service.data_available_from).to eq(nil)
    end
  end

  context '#average_school_day_peak_usage_kw' do
    it 'calculates the average school day peak usage in kw from a given asof date' do
      expect(service.average_peak_kw).to be_within(0.01).of(135.92)
    end
  end
end
