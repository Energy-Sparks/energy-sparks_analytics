# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Usage::PeakUsageBenchmarkingService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#estimated_savings' do
    it 'returns estimated savings when compared against an examplar or benchmark school' do
      service = Usage::PeakUsageBenchmarkingService.new(
        meter_collection: meter_collection,
        asof_date: Date.new(2022, 1, 1)
      )
      model = service.estimated_savings(versus: :exemplar_school)
      expect(model.kwh).to round_to_two_digits(105_187.78) # 105187.77999999828
      expect(model.£).to round_to_two_digits(16_440.45) # 16440.45410541508
      expect(model.co2).to round_to_two_digits(21_048.32) # 21048.319799999976
      expect(model.percent).to eq(nil)
    end
  end

  context '#average_peak_usage_kw' do
    it 'returns average peak usage kw when compared against an examplar or benchmark school' do
      service = Usage::PeakUsageBenchmarkingService.new(
        meter_collection: meter_collection,
        asof_date: Date.new(2022, 1, 1)
      )
      expect(service.average_peak_usage_kw(compare: :exemplar_school)).to round_to_two_digits(76.6) # 76.60130584192441
    end
  end
end
# rubocop:enable Metrics/BlockLength
