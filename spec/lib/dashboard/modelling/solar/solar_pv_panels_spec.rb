# frozen_string_literal: true
require 'spec_helper'

describe SolarPVPanels, type: :service do

  #ranges for amr data
  let(:start_date)         { Date.new(2023,1,1) }
  let(:end_date)           { Date.new(2023,1,31) }

  #unoccupied + occupied days
  let(:sunday)             { start_date }
  let(:monday)             { Date.new(2023, 1, 2) }

  let(:solar_pv_installation_date)  { start_date }
  let(:kwp)                         { 10.0 }
  let(:meter_attributes)   { [{ start_date: solar_pv_installation_date, kwp: kwp }] }

  #fake yield data from Sheffield
  let(:solar_yield)        { Array.new(10, 0.0) + Array.new(10, 0.25) + Array.new(8, 0.5) + Array.new(10, 0.25) + Array.new(10, 0.0)}

  let(:solar_pv)           { build(:solar_pv, :with_days,
      start_date: start_date,
      end_date: end_date,
      data_x48: solar_yield
    )
  }

  let(:pv_meter_map)       { PVMap.new }

  let(:is_holiday)         { false }
  let(:holidays)           { double('holidays') }

  let(:meter_collection)   { build(:meter_collection, holidays: holidays) }

  let(:kwh_data_x48)       { Array.new(10, 0.01) + Array.new(10, 0.15) + Array.new(8, 0.4) + Array.new(10, 0.25) + Array.new(10, 0.01) }

  let(:meter)              { build(:meter,
      meter_collection: meter_collection,
      amr_data: build(:amr_data, :with_days, day_count: 31,
        end_date: Date.new(2023,1,31), kwh_data_x48: kwh_data_x48)
    )
  }

  let(:service) { SolarPVPanels.new(meter_attributes, solar_pv)}

  before(:each) do
    allow(holidays).to receive(:holiday?).and_return(is_holiday)
    pv_meter_map[:mains_consume] = meter
  end

  context 'when generating synthetic data' do
    before(:each) do
      service.process(pv_meter_map, meter_collection)
    end

    it 'should populate the PV map with extra meters of the right type' do
      expect(pv_meter_map[:generation]).to_not be_nil
      expect(pv_meter_map[:generation].fuel_type).to eq :solar_pv
      expect(pv_meter_map.number_of_generation_meters).to eq 1

      expect(pv_meter_map[:export]).to_not be_nil
      expect(pv_meter_map[:export].fuel_type).to eq :exported_solar_pv

      expect(pv_meter_map[:self_consume]).to_not be_nil
      expect(pv_meter_map[:self_consume].fuel_type).to eq :solar_pv
    end

    it 'should produce synthetic meters with right date ranges' do
      [:export, :self_consume, :generation].each do |meter_type|
        if pv_meter_map[meter_type] != nil
          expect(pv_meter_map[meter_type].amr_data.start_date).to eq start_date
          expect(pv_meter_map[meter_type].amr_data.end_date).to eq end_date
        end
      end
    end

    it 'should calculate generation data' do
      #expected data is pv_yield * (capacity / 2.0) == solar_pv_yield * (kwp / 2.0)
      expect(pv_meter_map[:generation].amr_data.days_kwh_x48(sunday)).to eq [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end

    it 'should calculate export data' do
      days_data = pv_meter_map[:export].amr_data.days_kwh_x48(sunday)
      #should be exporting from periods 11-37 on the sunday based on AMR and solar data
      expect( days_data[11..37].all? {|hh| hh < 0.0 } ).to eq true

      days_data = pv_meter_map[:export].amr_data.days_kwh_x48(monday)
      #should not be exporting on the monday as school is occupied
      expect( days_data ).to eq Array.new(48, 0.0)
    end

    it 'should calculate self consumption data' do
      days_data = pv_meter_map[:self_consume].amr_data.days_kwh_x48(sunday)
      #should be consuming from periods 11-37 on the sunday based on AMR and solar data
      #TODO: think there's a bug in old calculation, as its showing self consumption when no solar generation
      puts days_data.inspect
      expect( days_data[11..37].all? {|hh| hh > 0.0 } ).to eq true

      days_data = pv_meter_map[:self_consume].amr_data.days_kwh_x48(monday)
      #should be consuming on the monday
      #TODO this could be better: could check that we're consuming ~pv output
      expect( days_data[11..37].all? {|hh| hh > 0.0 } ).to eq true
    end
  end

  context 'when overriding existing data' do
    it 'should skip days when school is unoccupied'
    it 'should calculate expected export'
    it 'should calculate generation data'
    it 'should calculate self consumption data'
  end

end
