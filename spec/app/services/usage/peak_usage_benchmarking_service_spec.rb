# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Usage::PeakUsageBenchmarkingService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }
  let(:service) do
    Usage::PeakUsageBenchmarkingService.new(
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

  context '#estimated_savings' do
    it 'returns estimated savings when compared against an examplar or benchmark school' do
      model = service.estimated_savings(versus: :exemplar_school)
      expect(model.kwh).to round_to_two_digits(105_187.78) # 105187.77999999828
      expect(model.£).to round_to_two_digits(16_440.45) # 16440.45410541508
      expect(model.co2).to round_to_two_digits(21_048.32) # 21048.319799999976
      expect(model.percent).to eq(nil)
    end
  end

  context '#average_peak_usage_kw' do
    it 'returns average peak usage kw when compared against an examplar or benchmark school' do
      expect(service.average_peak_usage_kw(compare: :exemplar_school)).to round_to_two_digits(59.32)
    end
  end
end
# rubocop:enable Metrics/BlockLength
