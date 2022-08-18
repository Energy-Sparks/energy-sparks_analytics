require 'spec_helper'

describe FormatEnergyUnit do

  let!(:value)   { 113.66216439927433 }

  context "ks2 formatting" do
    [
      { units: :£_0dp, expected: "&pound;114", medium: :html, type: String },
      { units: :£_0dp, expected: "£114",       medium: :text, type: String },
      { units: :£,     expected: "&pound;110", medium: :html, type: String },
      { units: :£,     expected: 113.66216439927433, medium: :raw,  type: Float }
    ].each do |config|
      it "formats value as #{config[:units]} to #{config[:medium]} as expected" do
        result = FormatEnergyUnit.format(config[:units], value, config[:medium])
        expect(result).to eq config[:expected]
        expect(result.class).to eq config[:type]
      end
    end
  end

  context "benchmark formatting" do
    [
      { units: :£_0dp, expected: "&pound;114", medium: :html, type: String },
      { units: :£_0dp, expected: "£114",       medium: :text, type: String },
      { units: :£,     expected: "&pound;114", medium: :html, type: String },
      { units: :£,     expected: 113.66216439927433, medium: :raw,  type: Float }
    ].each do |config|
      it "formats value as #{config[:units]} to #{config[:medium]} as expected" do
        result = FormatEnergyUnit.format(config[:units], value, config[:medium], false, false, :benchmark)
        expect(result).to eq config[:expected]
        expect(result.class).to eq config[:type]
      end
    end
  end

  context "energy expert formatting" do
    [
      { units: :£_0dp, expected: "&pound;114", medium: :html, type: String },
      { units: :£_0dp, expected: "£114",       medium: :text, type: String },
      { units: :£,     expected: "&pound;113.6621644", medium: :html, type: String },
      { units: :£,     expected: 113.66216439927433, medium: :raw,  type: Float }
    ].each do |config|
      it "formats value as #{config[:units]} to #{config[:medium]} as expected" do
        result = FormatEnergyUnit.format(config[:units], value, config[:medium], false, false, :energy_expert)
        expect(result).to eq config[:expected]
        expect(result.class).to eq config[:type]
      end
    end
  end

  context "'to pence' formatting" do
    [
      { units: :£_0dp, expected: "&pound;114", medium: :html, type: String },
      { units: :£_0dp, expected: "£114",       medium: :text, type: String },
      { units: :£,     expected: "&pound;113.66", medium: :html, type: String },
      { units: :£,     expected: 113.66216439927433, medium: :raw,  type: Float }
    ].each do |config|
      it "formats value as #{config[:units]} to #{config[:medium]} as expected" do
        result = FormatEnergyUnit.format(config[:units], value, config[:medium], false, false, :to_pence)
        expect(result).to eq config[:expected]
        expect(result.class).to eq config[:type]
      end
    end
  end

  context 'date formatting' do
    it 'formats Dates' do
      date = Date.new(2000,1,1)
      expect(FormatEnergyUnit.format(:date, date, :text)).to eq "Saturday  1 Jan 2000"
    end
    it 'formats String as a date' do
      expect(FormatEnergyUnit.format(:date, "2000-01-01", :text)).to eq "Saturday  1 Jan 2000"
    end
    it 'formats Date as a date time' do
      date = Date.new(2000,1,1)
      expect(FormatEnergyUnit.format(:datetime, date, :text)).to eq "Saturday  1 Jan 2000 00:00"
      date = DateTime.new(2000,1,1,14,40)
      expect(FormatEnergyUnit.format(:datetime, date, :text)).to eq "Saturday  1 Jan 2000 14:40"
    end
    it 'formats String as a date time' do
      expect(FormatEnergyUnit.format(:datetime, "2000-01-01", :text)).to eq "Saturday  1 Jan 2000 00:00"
    end
  end

  context 'validating units' do
    it 'identifies known units' do
      expect(FormatUnit.known_unit?(:£)).to be true
      expect(FormatUnit.known_unit?(:kwh_per_day)).to be true
      expect(FormatUnit.known_unit?(:unknown)).to be false
    end
    it 'throws exception when units are unknown' do
      expect {
        FormatUnit.format(:unknown, 10, :text, false)
      }.to raise_exception EnergySparksUnexpectedStateException
    end
    it 'does not throw exception when not strict' do
      expect(FormatUnit.format(:unknown, 10, :text, true)).to eq("10")
    end
  end

  context 'other scalars' do
    it 'does what?' do
      pry
    end
  end
end
