require 'spec_helper'

describe Usage::AnnualUsageBenchmarksService, type: :service do

  let(:asof_date)        { Date.new(2022, 2, 1) }
  let(:fuel_type)        { :electricity }
  let(:meter_collection) { @acme_academy }
  let(:service)          { Usage::AnnualUsageBenchmarksService.new(meter_collection, fuel_type, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    context 'for electricity' do
      context 'with enough data' do
        it 'returns true' do
          expect(service.enough_data?).to be true
        end
      end
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      context 'with enough data' do
        it 'returns true' do
          expect(service.enough_data?).to be true
        end
      end
    end
  end

  context '#annual_usage' do
    context 'for electricity' do
      it 'calculates the expected values for a benchmark school' do
        annual_usage = service.annual_usage(compare: :benchmark_school)
        expect(annual_usage.kwh).to round_to_two_digits(312325.0)
        expect(annual_usage.£).to round_to_two_digits(47484.71)
        expect(annual_usage.co2).to round_to_two_digits(59124.1)
      end
      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to round_to_two_digits(218627.5)
        expect(annual_usage.£).to round_to_two_digits(33239.3)
        expect(annual_usage.co2).to round_to_two_digits(41386.87)
      end
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      it 'calculates the expected values for a benchmark school' do
        annual_usage = service.annual_usage(compare: :benchmark_school)
        expect(annual_usage.kwh).to round_to_two_digits(542203.44)
        expect(annual_usage.£).to round_to_two_digits(16266.10)
        expect(annual_usage.co2).to round_to_two_digits(113862.72)
      end
      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to round_to_two_digits(502913.33)
        expect(annual_usage.£).to round_to_two_digits(15087.40)
        expect(annual_usage.co2).to round_to_two_digits(105611.8)
      end
    end
  end

  context '#estimate_savings' do
    context 'for electricity' do
      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to round_to_two_digits(137223.0)
        expect(savings.£).to round_to_two_digits(20862.87)
        expect(savings.co2).to round_to_two_digits(25976.74)
        expect(savings.percent).to round_to_two_digits(0.44)
      end
      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to round_to_two_digits(230920.5)
        expect(savings.£).to round_to_two_digits(35108.28)
        expect(savings.co2).to round_to_two_digits(43713.97)
        expect(savings.percent).to round_to_two_digits(1.06)
      end
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to round_to_two_digits(90129.45)
        expect(savings.£).to round_to_two_digits(2703.88)
        expect(savings.co2).to round_to_two_digits(18927.18)
        expect(savings.percent).to round_to_two_digits(0.17)
      end
      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to round_to_two_digits(129419.56)
        expect(savings.£).to round_to_two_digits(3882.59)
        expect(savings.co2).to round_to_two_digits(27178.11)
        expect(savings.percent).to round_to_two_digits(0.26)
      end
    end
  end

end
