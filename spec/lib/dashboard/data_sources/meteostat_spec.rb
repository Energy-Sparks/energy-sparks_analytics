require_relative '../../../../lib/dashboard/data_sources/meteostat'
require_relative '../../../../lib/dashboard/data_sources/meteostat_api'

describe MeteoStat do

  let(:latitude)    { 123 }
  let(:longitude)   { 456 }
  let(:start_date)  { Date.parse('20210127') }
  let(:end_date)    { Date.parse('20210128') }

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

  let(:expected_nearest_weather_stations) do
    [
      {:name=>"Nottingham Weather Centre", :latitude=>53, :longitude=>-1.25, :elevation=>117, :distance=>39.4},
      # {:name=>"Newton / Saxondale", :latitude=>52.9667, :longitude=>-0.9833, :elevation=>55, :distance=>51.5},
      # {:name=>"Sturgate", :latitude=>53.3811, :longitude=>-0.6856, :elevation=>9, :distance=>51.9},
      # {:name=>"Leeds Weather Centre", :latitude=>53.8, :longitude=>-1.55, :elevation=>47, :distance=>52.5},
      # {:name=>"Manchester Airport", :latitude=>53.35, :longitude=>-2.2833, :elevation=>69, :distance=>54.6},
      # {:name=>"East Midlands / Castle Donington", :latitude=>52.8333, :longitude=>-1.3333, :elevation=>94, :distance=>55.9},
      # {:name=>"Church Fenton", :latitude=>53.8333, :longitude=>-1.2, :elevation=>9, :distance=>58.5},
      # {:name=>"Scampton", :latitude=>53.3069, :longitude=>-0.5481, :elevation=>62, :distance=>60.8}
    ]
  end


  describe 'historic_temperatures' do

    let(:temperature_json)        { JSON.parse(File.read('spec/fixtures/meteostat/historic_temperatures.json')) }

    before do
      expect_any_instance_of(MeteoStatApi).to receive(:historic_temperatures).and_return(temperature_json)
    end

    it 'returns expected temperatures' do
      expect(MeteoStat.new.historic_temperatures(latitude, longitude, start_date, end_date)).to eq(expected_historic_temperatures)
    end
  end

  describe 'nearest_weather_stations' do

    let(:nearest_json)     { JSON.parse(File.read('spec/fixtures/meteostat/nearby_stations.json')) }
    let(:find_json)        { JSON.parse(File.read('spec/fixtures/meteostat/find_station.json')) }

    before do
      expect_any_instance_of(MeteoStatApi).to receive(:nearby_stations).and_return(nearest_json)
      expect_any_instance_of(MeteoStatApi).to receive(:find_station).and_return(find_json)
    end

    it 'returns expected stations' do
      expect(MeteoStat.new.nearest_weather_stations(latitude, longitude, 1)).to eq(expected_nearest_weather_stations)
    end
  end
end
