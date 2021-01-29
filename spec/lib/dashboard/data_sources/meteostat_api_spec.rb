require_relative '../../../../lib/dashboard/data_sources/meteostat_api'

describe MeteoStatApi do

  before(:each) do
    expect_any_instance_of(Faraday::Connection).to receive(:get).exactly(attempts).times.and_return(response)
  end

  describe 'when response is 200' do
    let(:attempts) { 1 }
    let(:response) { double(status: 200, body: '{"a": "1"}') }

    it 'retries 3 times then raises error' do
      expect(MeteoStatApi.new('123').find_station('xyz')).to eq({'a'=>'1'})
    end
  end

  describe 'when response is 429' do
    let(:attempts) { 3 }
    let(:response) { double(status: 429) }

    it 'retries 3 times then raises error' do
      expect{
        MeteoStatApi.new('123').find_station('xyz')
      }.to raise_error(MeteoStatApi::RateLimitError)
    end
  end

  describe 'when response is other http error' do
    let(:attempts) { 1 }
    let(:response) { double(status: 404, body: 'some stuff') }

    it 'tries once only then raise error' do
      expect{
        MeteoStatApi.new('123').find_station('xyz')
      }.to raise_error(MeteoStatApi::HttpError)
    end
  end
end
