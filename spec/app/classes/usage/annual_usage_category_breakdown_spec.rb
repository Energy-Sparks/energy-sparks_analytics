# frozen_string_literal: true

require 'spec_helper'

describe Usage::AnnualUsageCategoryBreakdown, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }
  let(:service) do
    Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity).usage_breakdown
  end

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context 'total' do
    it 'returns a combined usage metric for total annual kwh and co2' do
      model = service.total
      expect(model.kwh).to be_within(0.01).of(408_845.4)
      expect(model.co2).to be_within(0.01).of(68_135.42)
      expect(model.£).to be_within(0.01).of(61_326.81)
    end
  end

  describe '#potential_savings' do
    it 'returns a combined usage metric of potential kwh, co2, and percent savings compared to an exemplar school' do
      exemplar_comparison = service.potential_savings(versus: :exemplar_school)
      expect(exemplar_comparison.kwh).to be_within(0.01).of(56_547.26)
      expect(exemplar_comparison.percent).to be_within(0.01).of(0.14)
      expect(exemplar_comparison.£).to be_within(0.01).of(8482.09)
    end
  end
end
