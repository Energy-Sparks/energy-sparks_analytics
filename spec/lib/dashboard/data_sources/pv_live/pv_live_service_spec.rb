require 'spec_helper'

describe DataSources::PVLiveService, type: :service do

  let(:service)     { DataSources::PVLiveService.new }

  let(:latitude)  { 0.513751e2 }
  let(:longitude) { -0.236172e1 }

  context '#find_nearest_areas' do

    let(:gsp_list)  { JSON.parse(File.read('spec/fixtures/pv_live/gsp_list.json'), symbolize_names: true) }

    before(:each) do
      expect_any_instance_of(DataSources::PVLiveAPI).to receive(:gsp_list).and_return(gsp_list)
    end

    it 'returns expected list of areas' do
      nearest_areas = service.find_nearest_areas(latitude, longitude)
      expect(nearest_areas.length).to eq 5
      expect(nearest_areas.first[:gsp_name]).to eql("MELK_1")
    end
  end

  context '#historic_solar_pv_data' do
      let(:data)  { JSON.parse(File.read('spec/fixtures/pv_live/0.json'), symbolize_names: true)}
      let(:start_date) { Date.new(2021,01,01) }
      let(:end_date)   { Date.new(2021,01,02) }

      before(:each) do
        expect_any_instance_of(DataSources::PVLiveAPI).to receive(:gsp).and_return(data)
      end

      it 'returns reformatted data' do
        solar_pv_data, _missing_date_times, _whole_day_substitutes = service.historic_solar_pv_data(0, latitude, longitude, start_date , end_date)

        expect(solar_pv_data[start_date].length).to eq 48
        #2021-01-01T09:00:00Z, 43.0 / 13080.0
        expect(solar_pv_data[start_date][18]).to eq 0.003287461773700306

        expect(solar_pv_data[end_date].length).to eq 48
      end

  end
end
