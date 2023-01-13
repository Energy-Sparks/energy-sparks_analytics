require 'spec_helper'

describe UsageBreakdown::BenchmarkService, type: :service do
  let(:school)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#initialize' do
    it 'fails with an invalid meter type passed' do
      expect { UsageBreakdown::BenchmarkService.new(school: school, fuel_type: :not_a_fuel_type) }.to raise_error('Invalid fuel type')
    end

    it 'initialises with a valid fuel type passed' do
      UsageBreakdown::BenchmarkService::VALID_FUEL_TYPES.each do |fuel_type|
        expect { UsageBreakdown::BenchmarkService.new(school: school, fuel_type: fuel_type) }.not_to raise_error
      end
    end
  end

  context '#calculate' do
    it 'runs the calculation for electricity meters' do
      UsageBreakdown::BenchmarkService.new(school: school, fuel_type: :electricity)
    end
  end
end
