require 'spec_helper'

describe Baseload::BaseloadBenchmarkingService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:service)        { Baseload::BaseloadBenchmarkingService.new(@acme_academy, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#average_baseload_kw' do
    it 'calculates baseload for a benchmark school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect( service.average_baseload_kw(compare: :benchmark_school) ).to eq 24
    end

    it 'calculated baseload for an exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect( service.average_baseload_kw(compare: :exemplar_school) ).to eq 14.399999999999999
    end
  end

  context '#baseload_usage' do
    it 'calculates usage for a benchmark school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.baseload_usage(compare: :benchmark_school)
      expect(usage.kwh).to eq 210240.0
      expect(usage.£).to eq 31964.093206710168
      expect(usage.co2).to eq 39799.09132084723
    end

    it 'calculates usage for an exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.baseload_usage(compare: :exemplar_school)
      expect(usage.kwh).to eq 126143.99999999999
      expect(usage.£).to eq 19178.455924026097
      expect(usage.co2).to eq 23879.454792508335
    end
  end

  context '#estimated_savings' do
    it 'calculates savings vs benchmark school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.estimated_savings(versus: :benchmark_school)
      expect(usage.kwh).to eq 2761.7999999999593
      expect(usage.£).to eq 419.8936102468171
      expect(usage.co2).to eq 522.8174011126058
    end

    it 'calculates savings vs exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.estimated_savings(versus: :exemplar_school)
      expect(usage.kwh).to eq 86857.79999999997
      expect(usage.£).to eq 13205.530892930885
      expect(usage.co2).to eq 16442.453929451498
    end
  end

end
