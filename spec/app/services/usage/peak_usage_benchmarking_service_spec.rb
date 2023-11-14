# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Usage::PeakUsageBenchmarkingService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }
  let(:service) do
    described_class.new(
      meter_collection: meter_collection,
      asof_date: Date.new(2022, 1, 1)
    )
  end

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  describe '#enough_data?' do
    it 'returns true if there is a years worth of data' do
      expect(service.enough_data?).to eq(true)
    end
  end

  describe '#determines when data is available' do
    it 'returns the date that meter data is available from' do
      # returns nil as days_of_data >= days_required
      expect(service.data_available_from).to eq(nil)
    end
  end

  describe '#estimated_savings' do
    it 'returns estimated savings when compared against an benchmark school' do
      savings = service.estimated_savings(versus: :benchmark_school)
      expect(savings.kwh).to be_within(0.01).of(22_352.35)
      expect(savings.£).to be_within(0.01).of(2856.26)
      expect(savings.co2).to be_within(0.01).of(4500.11)
      expect(savings.percent).to eq(nil)
    end

    it 'returns estimated savings when compared against an examplar school' do
      savings = service.estimated_savings(versus: :exemplar_school)
      expect(savings.kwh).to be_within(0.01).of(33_607.53)
      expect(savings.£).to be_within(0.01).of(4279.17)
      expect(savings.co2).to be_within(0.01).of(6727.27)
      expect(savings.percent).to eq(nil)
    end
  end

  describe '#average_peak_usage_kw' do
    it 'returns average peak usage kw when compared against an examplar school' do
      expect(service.average_peak_usage_kw(compare: :exemplar_school)).to be_within(0.01).of(107.63)
    end

    it 'returns average peak usage kw when compared against a benchmark school' do
      expect(service.average_peak_usage_kw(compare: :benchmark_school)).to be_within(0.01).of(120.13)
    end
  end
end
# rubocop:enable Metrics/BlockLength
