require 'spec_helper'
require 'faraday/adapter/test'

describe MeterReadingsFeeds::GeoApi do

  let(:success)     { true }
  let(:status)      { 200 }
  let(:response)    { double(success?: success, status: status, body: body.to_json) }

  context '#login' do

    let(:expected_headers)  { { 'Accept': 'application/json', 'Content-Type': 'application/json' } }
    let(:expected_url)      { MeterReadingsFeeds::GeoApi::BASE_URL + '/userapi/account/login' }
    let(:expected_payload)  { { emailAddress: username, password: password }.to_json }
    let(:body)              { {token: 'abc123'} }

    context 'with credentials' do

      let(:username) { 'myUser' }
      let(:password) { 'myPass' }

      before :each do
        expect(Faraday).to receive(:post).with(expected_url, expected_payload, expected_headers).and_return(response)
      end

      it "calls the login endpoint and returns token" do
        token = MeterReadingsFeeds::GeoApi.new(username: username, password: password).login
        expect(token).to eq('abc123')
      end
    end

    context 'with missing credential' do

      let(:password) { '' }

      it "raises error" do
        expect {
          MeterReadingsFeeds::GeoApi.new(username: username, password: password).login
        }.to raise_error
      end
    end
  end

  context '#trigger_fast_update' do

    let(:expected_url)      { MeterReadingsFeeds::GeoApi::BASE_URL + '/supportapi/system/trigger-fastupdate/' + system_id}
    let(:expected_headers)  { { 'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': "Bearer #{token}" } }
    let(:system_id)         { 'xyz987' }
    let(:body)              { '' }

    context 'with token' do

      let(:token) { 'abc123' }

      before :each do
        expect(Faraday).to receive(:get).with(expected_url, nil, expected_headers).and_return(response)
      end

      it "calls the trigger fast update" do
        ret = MeterReadingsFeeds::GeoApi.new(token: token).trigger_fast_update(system_id)
        expect(ret).to eq('')
      end
    end

    context 'with missing token' do
      it "raises error" do
        expect {
          ret = MeterReadingsFeeds::GeoApi.new(token: token).trigger_fast_update(system_id)
        }.to raise_error
      end
    end
  end
end
