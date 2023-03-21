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
    it 'returns estimated savings when compared against an benchmark school' do
      savings = service.estimated_savings(versus: :benchmark_school)
      expect(savings.kwh).to round_to_two_digits(22352.35)
      expect(savings.£).to round_to_two_digits(3516.65)
      expect(savings.co2).to round_to_two_digits(4500.11)
      expect(savings.percent).to eq(nil)
    end

    it 'returns estimated savings when compared against an examplar school' do
      savings = service.estimated_savings(versus: :exemplar_school)
      expect(savings.kwh).to round_to_two_digits(33607.53) # 33607.53199999968
      expect(savings.£).to round_to_two_digits(5288.69) # 5288.687824395379
      expect(savings.co2).to round_to_two_digits(6727.27) # 6727.269323999998
      expect(savings.percent).to eq(nil)
    end
  end

  context '#average_peak_usage_kw' do
    it 'returns average peak usage kw when compared against an examplar school' do
      expect(service.average_peak_usage_kw(compare: :exemplar_school)).to round_to_two_digits(107.63)
    end
    it 'returns average peak usage kw when compared against a benchmark school' do
      expect(service.average_peak_usage_kw(compare: :benchmark_school)).to round_to_two_digits(120.13)
    end
  end
end
# rubocop:enable Metrics/BlockLength
