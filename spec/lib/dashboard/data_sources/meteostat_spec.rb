require_relative '../../../../lib/dashboard/data_sources/meteostat'
require_relative '../../../../lib/dashboard/data_sources/meteostat_api'

describe MeteoStat do

  let(:latitude)    { 123 }
  let(:longitude)   { 456 }

  describe 'historic_temperatures' do

    let(:expected_historic_temperatures) do
      {
        :temperatures=>
          {
            Date.parse('Wed, 27 Jan 2021')=>[4.9, 4.95, 5.0, 5.1, 5.2, 5.25, 5.3, 5.5, 5.7, 5.75, 5.8, 5.85, 5.9, 5.9, 5.9, 5.95, 6.0, 6.2, 6.4, 6.6, 6.8, 7.15, 7.5, 7.8, 8.1, 8.4, 8.7, 8.9, 9.1, 8.9, 8.7, 8.35, 8.0, 7.5, 7.0, 6.85, 6.7, 6.35, 6.0, 5.9, 5.8, 6.0, 6.2, 6.1, 6.0, 6.05, 6.1, 6.2],
            Date.parse('Thu, 28 Jan 2021')=>[6.3, 6.3, 6.3, 6.3, 6.3, 6.3, 6.3, 6.2, 6.1, 6.15, 6.2, 6.05, 5.9, 5.75, 5.6, 5.55, 5.5, 5.6, 5.7, 5.9, 6.1, 6.4, 6.7, 7.05, 7.4, 7.75, 8.1, 8.45, 8.8, 9.0, 9.2, 9.0, 8.8, 8.45, 8.1, 8.05, 8.0, 8.1, 8.2, 8.2, 8.2, 8.2, 8.2, 8.3, 8.4, 8.45, 8.5, 8.5]
          },
        :missing=>[]
      }
    end

    let(:start_date)  { Date.parse('20210127') }
    let(:end_date)    { Date.parse('20210128') }
    let(:temperature_json)        { JSON.parse(File.read('spec/fixtures/meteostat/historic_temperatures.json')) }

    before do
      expect_any_instance_of(MeteoStatApi).to receive(:historic_temperatures).exactly(api_call_count).times.and_return(temperature_json)
    end

    describe 'returns expected temperature data' do

      let(:api_call_count) { 1 }

      it 'returns expected temperatures' do
        expect(MeteoStat.new.historic_temperatures(latitude, longitude, start_date, end_date)).to eq(expected_historic_temperatures)
      end

    end

    describe 'for longer date ranges' do

      let(:api_call_count) { 3 }
      let(:start_date)  { Date.parse('20210101') }
      let(:end_date)    { Date.parse('20210128') }

      it 'requests 10 days at a time for 28 day span but shows 24 hours * 26 days missing' do
        data = MeteoStat.new.historic_temperatures(latitude, longitude, start_date, end_date)
        expect(data[:missing].count).to eq(24*26)
      end

    end
  end

  describe 'nearest_weather_stations' do

    describe 'when stations exist' do
      let(:expected_nearest_weather_stations) do
        [
          {:name=>"Nottingham Weather Centre", :latitude=>53, :longitude=>-1.25, :elevation=>117, :distance=>0},
          {:name=>"Newton / Saxondale", :latitude=>52.9667, :longitude=>-0.9833, :elevation=>55, :distance=>18.2},
        ]
      end

      let(:nearest_json)     { JSON.parse(File.read('spec/fixtures/meteostat/nearby_stations.json')) }
      let(:find_1_json)        { JSON.parse(File.read('spec/fixtures/meteostat/find_station_1.json')) }
      let(:find_2_json)        { JSON.parse(File.read('spec/fixtures/meteostat/find_station_2.json')) }

      before do
        expect_any_instance_of(MeteoStatApi).to receive(:nearby_stations).and_return(nearest_json)
        expect_any_instance_of(MeteoStatApi).to receive(:find_station).with('03354').and_return(find_1_json)
        expect_any_instance_of(MeteoStatApi).to receive(:find_station).with('EGXN0').and_return(find_2_json)
      end

      it 'returns expected stations' do
        expect(MeteoStat.new.nearest_weather_stations(latitude, longitude, 2)).to eq(expected_nearest_weather_stations)
      end
    end

    describe 'when no stations found' do
      before do
        expect_any_instance_of(MeteoStatApi).to receive(:nearby_stations).and_return({})
      end

      it 'handles it' do
        expect(MeteoStat.new.nearest_weather_stations(latitude, longitude, 2)).to eq([])
      end
    end
  end
end
