require 'spec_helper'
require 'faraday/adapter/test'

describe MeterReadingsFeeds::N3rgyDataApi do

  let(:stubs)           { Faraday::Adapter::Test::Stubs.new }
  let(:connection)      { Faraday.new { |b| b.adapter(:test, stubs) } }
  let(:base_url)        { "http://api.example.org" }
  let(:api_token)       { "token" }

  let(:api)             { MeterReadingsFeeds::N3rgyDataApi.new(api_token, base_url, connection)}

  let(:mpxn)            { "123456789100" }
  let(:fuel_type)       { :electricity }

  let(:headers)         { {"Authorization": "foo"} }

  after(:all) do
    Faraday.default_connection = nil
  end

  context '#new' do
    it "adds auth header when constructing client" do
      allow(Faraday).to receive(:new).with(base_url, headers: { 'Authorization' => api_token }).and_call_original
      MeterReadingsFeeds::N3rgyDataApi.new(api_token, base_url)
    end
  end

  context '#status' do
    let(:response) {
      {
        "entries" => ["gas", "electricity"],
        "resource" => "/2234567891000/",
        "responseTimestamp" => "2021-02-08T19:50:35.929Z"
      }
    }
    it 'requests correct url' do
      stubs.get("/123456789100/") do |env|
        [200, {}, response.to_json]
      end
      resp = api.status(mpxn)
      expect(resp["entries"]).to eql ["gas", "electricity"]
      stubs.verify_stubbed_calls
    end

    context 'with auth failure' do
      let(:response) { {"message":"Unauthorized"} }
      it 'raises error' do
        stubs.get("/123456789100/") do |env|
          [401, {}, response.to_json]
        end
        expect{ api.status(mpxn) }.to raise_error(MeterReadingsFeeds::N3rgyDataApi::NotAuthorised, "Unauthorized")
        stubs.verify_stubbed_calls
      end
    end

    context 'with unknown meter' do
      let(:response) {
        {
          "errors":[
            {"code":404,"message":"No property could be found with identifier '123456789100'"}
          ]
        }
      }
      it 'raises error' do
        stubs.get("/123456789100/") do |env|
          [404, {}, response.to_json]
        end
        expect{ api.status(mpxn) }.to raise_error(MeterReadingsFeeds::N3rgyDataApi::NotFound, "No property could be found with identifier '123456789100'")
        stubs.verify_stubbed_calls
      end
    end

    context 'with consent failure' do
      let(:response) {
        {
          "errors":[
            {"code":403,"message":"You do not have a registered consent to access \u0027123456789100\u0027"}
          ]
        }
      }
      it 'raises error' do
        stubs.get("/123456789100/") do |env|
          [403, {}, response.to_json]
        end
        expect{ api.status(mpxn) }.to raise_error(MeterReadingsFeeds::N3rgyDataApi::NotAllowed)
        stubs.verify_stubbed_calls
      end
    end

  end

  context '#get_elements' do
    let(:response) {
      {
        "entries" => [
          1,
          2
        ],
        "resource" => "1234567891001/electricity/consumption",
        "responseTimestamp"=>"2021-02-23T16:36:14.801Z"
      }
    }

    it 'requests correct url' do
      stubs.get("/123456789100/electricity/consumption/") do |env|
        [200, {}, response.to_json]
      end
      elements = api.get_elements(mpxn: mpxn, fuel_type: fuel_type)
      expect(elements["entries"]).to eql [1, 2]
      stubs.verify_stubbed_calls
    end

    it 'supports other reading types' do
      stubs.get("/123456789100/electricity/production/") do |env|
        [200, {}, response.to_json]
      end
      elements = api.get_elements(mpxn: mpxn, fuel_type: fuel_type, reading_type: "production")
      expect(elements["entries"]).to eql [1, 2]
      stubs.verify_stubbed_calls

    end
  end

  context '#get_consumption_data' do
    let(:response)      { JSON.parse(File.read('spec/fixtures/n3rgy/get_consumption_data.json')) }

    it 'requests correct url' do
      stubs.get("/123456789100/electricity/consumption/1") do |env|
        [200, {}, response.to_json]
      end
      data = api.get_consumption_data(mpxn: mpxn, fuel_type: fuel_type)
      expect(data["resource"]).to eql "/2234567891000/electricity/consumption/1"
      stubs.verify_stubbed_calls
    end

    it 'adds dates' do
      stubs.get("/123456789100/electricity/consumption/1") do |env|
        expect(env.params).to eql("start" => "20200101", "end" => "20200102")
        [200, {}, response.to_json]
      end
      date = Date.parse("2020-01-01")
      data = api.get_consumption_data(mpxn: mpxn, fuel_type: fuel_type, start_date: date, end_date: date)
      expect(data["resource"]).to eql "/2234567891000/electricity/consumption/1"
      stubs.verify_stubbed_calls
    end

  end

  context '#get_tariff_data' do
    let(:response)      { JSON.parse(File.read('spec/fixtures/n3rgy/get_tariff_data.json')) }
    it 'requests correct url' do
      stubs.get("/123456789100/electricity/tariff/1") do |env|
        [200, {}, response.to_json]
      end
      data = api.get_tariff_data(mpxn: mpxn, fuel_type: fuel_type)
      expect(data["resource"]).to eql "/2234567891000/electricity/tariff/1"
      stubs.verify_stubbed_calls
    end

  end

  context '#read-inventory' do
    let(:inventory_url)      { 'https://read-inventory.data.n3rgy.com/files/3b80564b-fa21-451a-a8a1-2b4abb6bb8f6.json' }
    let(:response)     {
        {
          "status" => 200,
          "uuid" => "3b80564b-fa21-451a-a8a1-2b4abb6bb8f6",
          "uri" => inventory_url
        }
    }
    it 'requests correct url' do
      stubs.post("/read-inventory") do |env|
        expect(env.body).to eql({
          mpxns: ["123456789100"]
        }.to_json)
        [200, {}, response.to_json]
      end
      data = api.read_inventory(mpxn: mpxn)
      expect(data["uuid"]).to eql "3b80564b-fa21-451a-a8a1-2b4abb6bb8f6"
      stubs.verify_stubbed_calls
    end
  end

  context 'fetch' do
    let(:response) {
      {
        "entries" => ["gas", "electricity"],
        "resource" => "/2234567891000/",
        "responseTimestamp" => "2021-02-08T19:50:35.929Z"
      }
    }

    it 'requests correct url' do
      stubs.get("/123456789100") do |env|
        [200, {}, response.to_json]
      end
      data = api.fetch("/123456789100")
      expect(data["entries"]).to eql ["gas", "electricity"]
      stubs.verify_stubbed_calls
    end
  end
end
