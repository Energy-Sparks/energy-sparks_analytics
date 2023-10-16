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
        expect(annual_usage.kwh).to be_within(0.01).of(312325.0)
        expect(annual_usage.£).to be_within(0.01).of(46848.75)
        expect(annual_usage.co2).to be_within(0.01).of(52182.13)
      end
      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to be_within(0.01).of(218627.5)
        expect(annual_usage.£).to be_within(0.01).of(32794.12)
        expect(annual_usage.co2).to be_within(0.01).of(36527.49)
      end
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      it 'calculates the expected values for a benchmark school' do
        annual_usage = service.annual_usage(compare: :benchmark_school)
        expect(annual_usage.kwh).to be_within(0.01).of(541711.87)
        expect(annual_usage.£).to be_within(0.01).of(16251.35)
        expect(annual_usage.co2).to be_within(0.01).of(113759.49)
      end
      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to be_within(0.01).of(502457.39)
        expect(annual_usage.£).to be_within(0.01).of(15073.72)
        expect(annual_usage.co2).to be_within(0.01).of(105516.05)
      end
    end
  end

  context '#estimate_savings' do
    context 'for electricity' do
      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to be_within(0.01).of(137223.0)
        expect(savings.£).to be_within(0.01).of(20583.45)
        expect(savings.co2).to be_within(0.01).of(22926.72)
        expect(savings.percent).to be_within(0.01).of(0.44)
      end
      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to be_within(0.01).of(230920.5)
        expect(savings.£).to be_within(0.01).of(34638.07)
        expect(savings.co2).to be_within(0.01).of(38581.36)
        expect(savings.percent).to be_within(0.01).of(1.06)
      end
    end
    context 'for gas' do
      let(:fuel_type)        { :gas }
      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to be_within(0.01).of(90621.01)
        expect(savings.£).to be_within(0.01).of(2718.63)
        expect(savings.co2).to be_within(0.01).of(19030.41)
        expect(savings.percent).to be_within(0.01).of(0.16)
      end
      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to be_within(0.01).of(129875.49)
        expect(savings.£).to be_within(0.01).of(3896.26)
        expect(savings.co2).to be_within(0.01).of(27273.85)
        expect(savings.percent).to be_within(0.01).of(0.25)
      end
    end
  end

end
