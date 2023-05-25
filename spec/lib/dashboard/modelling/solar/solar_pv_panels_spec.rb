# frozen_string_literal: true
require 'spec_helper'

describe SolarPVPanels, type: :service do

  let(:start_date)                  { Date.new(2023,1,1) }
  let(:end_date)                    { Date.new(2023,1,31) }

  let(:solar_pv_installation_date)  { start_date }
  let(:kwp)                         { 12.0 }
  let(:meter_attributes)   { [{ start_date: solar_pv_installation_date, kwp: kwp }] }

  let(:solar_pv)           { build(:solar_pv, :with_days, start_date: start_date, end_date: end_date) }

  let(:pv_meter_map)             { PVMap.new }

  let(:is_holiday)         { false }
  let(:holidays)           { double('holidays') }

  let(:meter_collection)   { build(:meter_collection, holidays: holidays) }

  let(:meter)              { build(:meter, meter_collection: meter_collection, amr_data: build(:amr_data, :with_days, day_count: 31, end_date: Date.new(2023,1,31))) }

  let(:service) { SolarPVPanels.new(meter_attributes, solar_pv)}

  before(:each) do
    allow(holidays).to receive(:holiday?).and_return(is_holiday)
    pv_meter_map[:mains_consume] = meter
  end

  context 'when generating synthetic data' do
    it 'should skip days when school is unoccupied'

    it 'should populate the PV map' do
      x = service.process(pv_meter_map, meter_collection)
      puts x
      puts pv_meter_map.inspect
    end

    it 'should calculate expected export'
    it 'should calculate generation data'
    it 'should calculate self consumption data'
  end

  context 'when overriding existing data' do
    it 'should skip days when school is unoccupied'
    it 'should calculate expected export'
    it 'should calculate generation data'
    it 'should calculate self consumption data'
  end

end
