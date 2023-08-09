require 'spec_helper'

describe Usage::AnnualUsageCategoryBreakdown, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  let(:service) { Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity).usage_breakdown }

  context 'total' do
    it 'returns a combined usage metric for total annual kwh and co2' do
      model = service.total
      expect(model.kwh).to round_to_two_digits(467398.40) # 467398.3999999999
      expect(model.co2).to round_to_two_digits(88492.64) # 88492.6392
      expect(model.£).to round_to_two_digits(71060.42) # 71060.41900000001
    end
  end

  context '#potential_savings' do
    it 'returns a combined usage metric of potential kwh, co2, and percent savings compared to an exemplar school' do
      exemplar_comparison = service.potential_savings(versus: :exemplar_school)
      expect(exemplar_comparison.kwh).to round_to_two_digits(66464.97)
      expect(exemplar_comparison.percent).to round_to_two_digits(0.14)
      expect(exemplar_comparison.£).to round_to_two_digits(10104.93)
    end
  end
end
