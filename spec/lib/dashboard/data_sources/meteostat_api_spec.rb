require_relative '../../../../lib/dashboard/data_sources/meteostat_api'

describe MeteoStatApi do

  before(:each) do
    expect_any_instance_of(Faraday::Connection).to receive(:get).and_return(response)
  end

  describe 'when response is 200' do
    let(:response) { double(status: 200, body: '{"a": "1"}') }

    it 'tries once then returns parsed data' do
      expect(MeteoStatApi.new('123').find_station('xyz')).to eq({'a'=>'1'})
    end
  end

  describe 'when response is http error' do
    let(:response) { double(status: 404, body: 'some stuff') }

    it 'tries once only then raise error' do
      expect{
        MeteoStatApi.new('123').find_station('xyz')
      }.to raise_error(MeteoStatApi::HttpError)
    end
  end
end
