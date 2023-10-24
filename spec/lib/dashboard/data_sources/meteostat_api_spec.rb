# frozen_string_literal: true

require_relative '../../../../lib/dashboard/data_sources/weather/historic/meteostat_api'

describe MeteoStatApi do
  let(:status) { 200 }
  let(:response) { double(status: status, body: '{"a": "1"}') }

  before do
    allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(response)
  end

  describe 'when rate limiting' do
    it 'is limited' do
      start_time = Time.now
      api = described_class.new('123')
      10.times { api.find_station('xyz') }
      end_time = Time.now
      expect(end_time).to be > start_time + 2
    end
  end

  describe 'when response is 200' do
    it 'returns parsed data' do
      expect(described_class.new('123').find_station('xyz')).to eq({ 'a' => '1' })
    end
  end

  describe 'when response is http error' do
    let(:status) { 404 }

    it 'tries once only then raise error' do
      expect  do
        described_class.new('123').find_station('xyz')
      end.to raise_error(MeteoStatApi::HttpError)
    end
  end
end
