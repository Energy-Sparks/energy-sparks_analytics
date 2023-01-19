require 'spec_helper'

describe Usage::AnnualUsageCalculationService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:meter)          { @acme_academy.aggregated_electricity_meters }
  let(:service)        { Usage::AnnualUsageCalculationService.new(meter, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#annual_usage' do
    context 'for electricity' do
      it 'calculates the expected values for this year' do
        annual_usage = service.annual_usage
        expect(annual_usage.kwh).to round_to_two_digits(449548.0)
        expect(annual_usage.£).to round_to_two_digits(68426.08)
        expect(annual_usage.co2).to round_to_two_digits(86754.08)
      end
      it 'calculates the expected values for last year' do
        annual_usage = service.annual_usage(period: :last_year)
        expect(annual_usage.kwh).to round_to_two_digits(402384.7)
        expect(annual_usage.£).to round_to_two_digits(60935.92)
        expect(annual_usage.co2).to round_to_two_digits(77977.43)
      end
    end
    context 'for gas' do
      let(:meter)          { @acme_academy.aggregated_heat_meters }
      it 'calculates the expected values for this year' do
        annual_usage = service.annual_usage
        expect(annual_usage.kwh).to round_to_two_digits(632332.89)
        expect(annual_usage.£).to round_to_two_digits(18969.99)
        expect(annual_usage.co2).to round_to_two_digits(132789.91)
      end
      it 'calculates the expected values for last year' do
        annual_usage = service.annual_usage(period: :last_year)
        expect(annual_usage.kwh).to round_to_two_digits(651034.37)
        expect(annual_usage.£).to round_to_two_digits(19531.03)
        expect(annual_usage.co2).to round_to_two_digits(136717.22)
      end
    end
  end

  context '#annual_usage_change_since_last_year' do
    context 'for electricity' do
      it 'calculates the expected values' do
        usage_change = service.annual_usage_change_since_last_year
        #values checked against electricity long term trend alert
        expect(usage_change.kwh).to round_to_two_digits(47163.3)
        expect(usage_change.£).to round_to_two_digits(7490.16)
        expect(usage_change.co2).to round_to_two_digits(8776.65)
        expect(usage_change.percent).to round_to_two_digits(0.12)
      end
    end
    context 'for gas' do
      let(:meter)          { @acme_academy.aggregated_heat_meters }
      it 'calculates the expected values' do
        usage_change = service.annual_usage_change_since_last_year
        #values checked against gas long term trend alert
        expect(usage_change.kwh).to round_to_two_digits(-18701.48)
        expect(usage_change.£).to round_to_two_digits(-561.04)
        expect(usage_change.co2).to round_to_two_digits(-3927.31)
        expect(usage_change.percent).to round_to_two_digits(-0.03)
      end
    end
  end


end
