require 'spec_helper'
require 'pry'

describe Baseload::BaseloadCalculationService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:meter)          { @acme_academy.aggregated_electricity_meters }
  let(:service)        { Baseload::BaseloadCalculationService.new(meter, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#average_baseload_kw' do
    it 'calculates baseload for a year' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect(service.average_baseload_kw).to eq 24.315273972602736
    end

    it 'calculates baseload for a year' do
      #numbers taken from running the AlertChangeInElectricityBaseloadShortTerm alert
      expect(service.average_baseload_kw(period: :week)).to eq 26.871874999999996
    end

  end

  context '#annual_baseload_usage' do
    it 'calculates the values' do
      usage = service.annual_baseload_usage

      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect(usage.kwh).to eq 213001.79999999996
      expect(usage.£).to eq 32383.98681695698
      expect(usage.co2).to eq 40321.90872195984
    end
  end
end
