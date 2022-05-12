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

end
