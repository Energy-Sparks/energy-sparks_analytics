require 'spec_helper'
require 'faraday/adapter/test'

describe DataSources::PVLiveAPI do

  let(:success)     { true }
  let(:status)      { 200 }
  let(:client)      { DataSources::PVLiveAPI.new }

  let(:response)    { double(success?: success, status: status, body: body.to_json) }

  before :each do
    expect(Faraday).to receive(:get).with(expected_url, expected_params, {}).and_return(response)
  end

  context 'gsp_list' do
    let(:expected_url) { DataSources::PVLiveAPI::BASE_URL + "/gsp_list" }
    let(:expected_params) { {} }

    context 'with success' do
      let(:body) {
        {
          "data": [
            [
              0,
              "NATIONAL",
              nil,
              nil,
              0,
              "_0",
              1
            ]
          ],
          "meta": [
          "gsp_id",
          "gsp_name",
          "gsp_lat",
          "gsp_lon",
          "pes_id",
          "pes_name",
          "n_ggds"
          ]
        }
      }
      it 'returns data' do
        expect( client.gsp_list ).to eql body
      end
    end
    context 'with error' do
      #they return a 200 error code with a JSON error document for errors
      let(:status)      { 200 }
      let(:response)    { double(success?: success, status: status, body: body.to_json) }

      let(:body) {
        {
          "error_code": nil,
          "error_description": "Unknown url parameter(s): {'XXX'}"
        }
      }
      it 'throws exception' do
        expect {
          client.gsp_list
        }.to raise_error(DataSources::PVLiveAPI::ApiFailure)
      end
    end
    context 'with 404' do
      let(:status)      { 404 }
      let(:response)    { double(success?: success, status: status, body: body) }
      let(:body)        { "<html>Some HTML</html>"}
      it 'throws exception' do
        expect {
          client.gsp_list
        }.to raise_error(DataSources::PVLiveAPI::ApiFailure)
      end
    end
  end

  context 'gsp' do
    let(:expected_url) { DataSources::PVLiveAPI::BASE_URL + "/gsp/0" }
    let(:expected_params) { {data_format: "json", extra_fields: "installedcapacity_mwp"} }
    let(:body) {
      {
        "data": [
          [
            0,
            "2021-10-11T13:30:00Z",
            1,
            4670.0
          ]
        ],
        "meta": [
          "gsp_id",
          "datetime_gmt",
          "n_ggds",
          "generation_mw"
        ]
      }
    }
    context 'with default params' do
      it 'calls expected url with params and returns the parsed response' do
        expect( client.gsp(0) ).to eql body
      end
    end
    context 'with dates' do
      let(:expected_params) { {data_format: "json", extra_fields: "installedcapacity_mwp", start: "2021-01-01T00:00:00Z", end: "2021-01-02T23:59:59Z"} }

      it 'calls expected url with params and returns the parsed response' do
        expect( client.gsp(0, Date.new(2021,01, 01), Date.new(2021,01,02)) ).to eql body
      end
    end

  end
end
