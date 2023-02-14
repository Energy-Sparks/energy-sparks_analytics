require 'spec_helper'

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
      expect(service.average_baseload_kw).to round_to_two_digits(24.32)
    end

    it 'calculates baseload for a week' do
      #numbers taken from running the AlertChangeInElectricityBaseloadShortTerm alert
      expect(service.average_baseload_kw(period: :week)).to round_to_two_digits(25.62)
    end

  end

  context '#annual_baseload_usage' do
    it 'calculates the values' do
      usage = service.annual_baseload_usage

      #numbers taken from running the AlertElectricityBaseloadVersusBenchmark alert
      expect(usage.kwh).to round_to_two_digits(213001.8)
      expect(usage.co2).to round_to_two_digits(40321.91)
      expect(usage.£).to round_to_two_digits(31818.29)
      expect(usage.percent).to be_nil
    end
    it 'includes percentage if needed' do
      usage = service.annual_baseload_usage(include_percentage: true)
      expect(usage.kwh).to round_to_two_digits(213001.8)
      expect(usage.co2).to round_to_two_digits(40321.91)
      expect(usage.£).to round_to_two_digits(31818.29)
      expect(usage.percent).to round_to_two_digits(0.47)
    end
  end
end
