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
      it 'calculates the expected values for a benchmark school'
      it 'calculates the expected values for an exemplar school'
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      it 'calculates the expected values for a benchmark school'
      it 'calculates the expected values for an exemplar school'
    end
  end

end
