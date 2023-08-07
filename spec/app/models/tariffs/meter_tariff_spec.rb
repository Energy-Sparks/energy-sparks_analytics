require 'spec_helper'

describe MeterTariff do

  let(:tariff_attribute) { create_accounting_tariff_generic(type: :differential, rates: create_old_differential_rate) }

  let(:meter) { double(:meter) }

  let(:meter_tariff)      { MeterTariff.new(meter, tariff_attribute) }

  before(:each) do
    expect(meter).to receive(:mpxn).and_return("123456789")
    expect(meter).to receive(:amr_data).and_return(nil)
    expect(meter).to receive(:fuel_type).and_return(:electricity)
  end
  context '.initialize' do
    it 'assigns the attributes' do
      expect(meter_tariff.tariff).to eq tariff_attribute
      expect(meter_tariff.fuel_type).to eq :electricity
    end
  end

  context '.default?' do
    context 'with default key' do
      it 'identifies default' do
        expect(meter_tariff.default?).to eq false
        tariff_attribute[:default] = true
        expect(meter_tariff.default?).to eq true
      end
    end
  end

  context '.dcc' do
    it 'identifies dcc tariff' do
      expect(meter_tariff.dcc?).to eq false
      tariff_attribute[:source] = :dcc
      expect(meter_tariff.dcc?).to eq true
    end
  end

  context '.weighted_cost' do
    let(:type)      { :nighttime_rate }
    let(:kwh_x48)   { Array.new(48, 1.0) }
    let(:cost)      { meter_tariff.weighted_cost(nil, kwh_x48, type) }
    it 'calculates the cost' do
      expect(cost).to eq Array.new(14, 0.0) + Array.new(34, 0.15)
    end
  end

end
