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
      expect( service.average_baseload_kw(compare: :benchmark_school) ).to round_to_two_digits(18.76)
    end

    it 'calculated baseload for an exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect( service.average_baseload_kw(compare: :exemplar_school) ).to round_to_two_digits(11.26)
    end
  end

  context '#baseload_usage' do
    it 'calculates usage for a benchmark school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.baseload_usage(compare: :benchmark_school)
      expect(usage.kwh).to round_to_two_digits(164328.84)
      expect(usage.£).to round_to_two_digits(24547.5)
      expect(usage.co2).to round_to_two_digits(31107.96)
    end

    it 'calculates usage for an exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.baseload_usage(compare: :exemplar_school)
      expect(usage.kwh).to round_to_two_digits(98597.3)
      expect(usage.£).to round_to_two_digits(14728.5)
      expect(usage.co2).to round_to_two_digits(18664.78)
    end
  end

  context '#estimated_savings' do
    it 'calculates savings vs benchmark school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.estimated_savings(versus: :benchmark_school)
      expect(usage.kwh).to round_to_two_digits(48672.96)
      expect(usage.£).to round_to_two_digits(7270.79)
      expect(usage.co2).to round_to_two_digits(9213.94)
    end

    it 'calculates savings vs exemplar school' do
      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      usage = service.estimated_savings(versus: :exemplar_school)
      expect(usage.kwh).to round_to_two_digits(114404.5)
      expect(usage.£).to round_to_two_digits(17089.79)
      expect(usage.co2).to round_to_two_digits(21657.13)
    end
  end

  context '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect( service.enough_data? ).to be true
        expect( service.data_available_from).to be nil
      end
    end
    context 'when theres is limited data' do
      #acme academy has data starting in 2019-01-13
      let(:asof_date)      { Date.new(2019, 1, 21) }
      it 'returns false' do
        expect( service.enough_data? ).to be false
        expect( service.data_available_from).to_not be nil
      end
    end
  end
end
