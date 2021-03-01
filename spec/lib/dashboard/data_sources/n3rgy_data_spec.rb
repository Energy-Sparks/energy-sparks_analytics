require 'spec_helper'

describe MeterReadingsFeeds::N3rgyData do

  describe 'when querying data' do

    let(:apikey)        { 'abc123' }
    let(:base_url)      { 'https://api.com' }
    let(:mpxn)          { 1234567891234 }
    let(:fuel_type)     { :electricity }
    let(:start_date)    { Date.parse('20190101') }
    let(:end_date)      { Date.parse('20190102') }

    describe 'status' do
      before :each do
        @api = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url)
      end

      context 'when not in DCC' do
        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:status).and_raise(MeterReadingsFeeds::N3rgyDataApi::NotFound)
        end
        it 'returns not found' do
          expect(MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).status(mpxn)).to eq(:unknown)
        end
      end

      context 'when in DCC but not consented' do
        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:status).and_raise(MeterReadingsFeeds::N3rgyDataApi::NotAllowed)
        end
        it 'returns not consented' do
          expect(MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).status(mpxn)).to eq(:consent_required)
        end
      end

      context 'when in DCC and consented' do
        let(:response) { {"entries" => ["gas", "electricity"], "resource" => "/2234567891000/", "responseTimestamp" => "2021-02-08T19:50:35.929Z"} }
        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:status).and_return(response)
        end
        it 'returns ok' do
          expect(MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).status(mpxn)).to eq(:available)
        end
      end
    end

    describe 'for tariffs' do

      let(:expected_first_day_tariffs)  { [0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992] }
      let(:expected_last_day_tariffs)   { [0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992, 0.15992] }
      let(:expected_standing_charge)    { 0.19541 }

      describe 'when date not specified' do
        it 'raises error' do
          expect {
            MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).tariffs(mpxn, fuel_type, start_date, nil)
          }.to raise_error(MeterReadingsFeeds::N3rgyData::BadParameters)
        end
      end

      describe 'when data exists' do

        let(:tariff_data)                 { JSON.parse(File.read('spec/fixtures/n3rgy/get_tariff_data.json')) }

        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:get_tariff_data).and_return(tariff_data)
        end

        it 'returns tariffs' do
          tariffs = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).tariffs(mpxn, fuel_type, start_date, end_date)
          expect(tariffs.keys).to match_array([:kwh_tariffs, :standing_charges, :missing_readings])

          expect(tariffs[:kwh_tariffs].count).to eq(2)
          expect(tariffs[:kwh_tariffs].keys).to eq([start_date, end_date])
          expect(tariffs[:kwh_tariffs][start_date]).to eq(expected_first_day_tariffs)
          expect(tariffs[:kwh_tariffs][end_date]).to eq(expected_last_day_tariffs)

          expect(tariffs[:standing_charges][start_date]).to eq(expected_standing_charge)
          expect(tariffs[:missing_readings]).to eq([])
        end

        describe 'when adjusting for bad sandbox electricity standing charge units' do
          it 'should convert standing charge from pence to pounds' do
            tariffs = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url, bad_electricity_standing_charge_units: true).tariffs(mpxn, fuel_type, start_date, end_date)
            expect(tariffs[:standing_charges][start_date]).to eq(100.0 * expected_standing_charge)
          end
        end
      end
    end

    describe 'for consumption' do

      let(:expected_first_day_readings) { [0.671,1.212,1.208,0.972,0.445,0.43,0.35,0.388,0.366,0.449,0.374,0.381,0.412,0.464,0.38,0.317,0.313,0.488,0.529,1.96,0.839,0.554,1.062,1.635,0.734,0.561,0.518,0.407,0.362,0.291,0.28,0.349,0.32,0.415,0.355,0.318,0.321,0.347,0.409,0.406,0.354,0.362,0.311,0.439,0.439,0.38,0.39,0.426] }
      let(:expected_last_day_readings) { [0.405,0.479,0.463,0.528,0.517,0.589,0.554,0.599,0.595,0.648,0.574,0.674,0.633,0.713,0.585,0.562,0.481,0.516,0.459,0.473,0.399,0.459,0.462,0.496,0.51,0.478,0.369,0.482,0.433,0.416,0.403,0.451,0.406,0.386,0.417,0.4,0.377,0.532,0.637,0.688,0.736,0.643,0.621,0.642,0.791,1.331,0.512,0.674] }

      describe 'when date not specified' do
        it 'raises error' do
          expect {
            MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).readings(mpxn, fuel_type, start_date, nil)
          }.to raise_error(MeterReadingsFeeds::N3rgyData::BadParameters)
          end
      end

      describe 'when data exists' do

        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:get_consumption_data).and_return(consumption_data)
        end

        let(:consumption_data)      { JSON.parse(File.read('spec/fixtures/n3rgy/get_consumption_data.json')) }

        it 'returns readings' do
          readings = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).readings(mpxn, fuel_type, start_date, end_date)
          expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

          expect(readings[fuel_type][:readings].count).to eq(2)
          expect(readings[fuel_type][:readings].keys).to eq([start_date, end_date])

          day_reading = readings[fuel_type][:readings][start_date]
          expect(day_reading.type).to eq('ORIG')
          expect(day_reading.kwh_data_x48).to eq(expected_first_day_readings)

          day_reading = readings[fuel_type][:readings][end_date]
          expect(day_reading.type).to eq('ORIG')
          expect(day_reading.kwh_data_x48).to eq(expected_last_day_readings)
        end

      end

      describe 'when no data' do

        let(:consumption_data) do
          {
            "resource"=>"/1234567891234/electricity/consumption/1",
            "responseTimestamp"=>"2021-02-04T16:36:14.801Z",
            "start"=>"202001010000",
            "end"=>"202001022359",
            "granularity"=>"halfhour",
            "values"=>[],
            "availableCacheRange"=>
              {
                "start"=>"201812242330",
                "end"=>"201905160230"
              },
            "unit"=>"kWh"
          }
        end

        before do
          expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:get_consumption_data).and_return(consumption_data)
        end

        it 'returns empty collection and 2 days * 48 half hours missing readings' do
          readings = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).readings(mpxn, fuel_type, start_date, end_date)
          expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

          expect(readings[fuel_type][:readings]).to eq({})
          expect(readings[fuel_type][:missing_readings].count).to eq(2 * 48)
        end

      end
    end

    describe 'for production' do

      let(:fuel_type)     { :exported_solar_pv }

      let(:expected_first_day_readings) { [0.671,1.212,1.208,0.972,0.445,0.43,0.35,0.388,0.366,0.449,0.374,0.381,0.412,0.464,0.38,0.317,0.313,0.488,0.529,1.96,0.839,0.554,1.062,1.635,0.734,0.561,0.518,0.407,0.362,0.291,0.28,0.349,0.32,0.415,0.355,0.318,0.321,0.347,0.409,0.406,0.354,0.362,0.311,0.439,0.439,0.38,0.39,0.426] }
      let(:expected_last_day_readings) { [0.405,0.479,0.463,0.528,0.517,0.589,0.554,0.599,0.595,0.648,0.574,0.674,0.633,0.713,0.585,0.562,0.481,0.516,0.459,0.473,0.399,0.459,0.462,0.496,0.51,0.478,0.369,0.482,0.433,0.416,0.403,0.451,0.406,0.386,0.417,0.4,0.377,0.532,0.637,0.688,0.736,0.643,0.621,0.642,0.791,1.331,0.512,0.674] }

      before do
        expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:get_production_data).and_return(consumption_data)
      end

      describe 'when data exists' do

        let(:consumption_data)      { JSON.parse(File.read('spec/fixtures/n3rgy/get_consumption_data.json')) }

        it 'returns readings' do
          readings = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).readings(mpxn, fuel_type, start_date, end_date)
          expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

          expect(readings[fuel_type][:readings].count).to eq(2)
          expect(readings[fuel_type][:readings].keys).to eq([start_date, end_date])

          day_reading = readings[fuel_type][:readings][start_date]
          expect(day_reading.type).to eq('ORIG')
          expect(day_reading.kwh_data_x48).to eq(expected_first_day_readings)

          day_reading = readings[fuel_type][:readings][end_date]
          expect(day_reading.type).to eq('ORIG')
          expect(day_reading.kwh_data_x48).to eq(expected_last_day_readings)
        end

      end

      describe 'when no data' do

        let(:consumption_data) do
          {
            "resource"=>"/1234567891234/electricity/consumption/1",
            "responseTimestamp"=>"2021-02-04T16:36:14.801Z",
            "start"=>"202001010000",
            "end"=>"202001022359",
            "granularity"=>"halfhour",
            "values"=>[],
            "availableCacheRange"=>
              {
                "start"=>"201812242330",
                "end"=>"201905160230"
              },
            "unit"=>"kWh"
          }
        end

        it 'returns empty collection and 2 days * 48 half hours missing readings' do
          readings = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).readings(mpxn, fuel_type, start_date, end_date)
          expect(readings[fuel_type].keys).to match_array([:mpan_mprn, :readings, :missing_readings])

          expect(readings[fuel_type][:readings]).to eq({})
          expect(readings[fuel_type][:missing_readings].count).to eq(2 * 48)
        end

      end
    end

    describe 'elements' do
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
      before do
        expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:get_elements).with(mpxn: mpxn, fuel_type: :electricity, reading_type: "consumption").and_return(response)
      end

      it 'returns elements' do
        contents = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).elements(mpxn, :electricity)
        expect(contents).to eq([1,2])
      end

    end

    describe 'for inventory' do

      let(:status)             { 200 }
      let(:inventory_url)      { 'https://read-inventory.data.n3rgy.com/files/3b80564b-fa21-451a-a8a1-2b4abb6bb8f6.json' }
      let(:inventory_data)     { {"status" => status, "uuid" => "3b80564b-fa21-451a-a8a1-2b4abb6bb8f6", "uri" => inventory_url} }
      let(:inventory_file)     { {"result"=>[{"mpxn"=>"1234567891234", "status"=>404, "message"=>"MPxN not found"}]} }

      before do
        expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:read_inventory).with(mpxn: mpxn).and_return(inventory_data)
        expect_any_instance_of(MeterReadingsFeeds::N3rgyDataApi).to receive(:fetch).with(inventory_url).and_return(inventory_file)
      end

      it 'returns inventory file contents' do
        contents = MeterReadingsFeeds::N3rgyData.new(api_key: apikey, base_url: base_url).inventory(mpxn)
        expect(contents).to eq(inventory_file)
      end
    end

  end
end
