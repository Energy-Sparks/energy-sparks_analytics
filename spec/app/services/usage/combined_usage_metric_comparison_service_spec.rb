# frozen_string_literal: true

require 'spec_helper'

describe Usage::CombinedUsageMetricComparisonService, type: :service do
  context '#subtract' do
    it 'calculates the kwh, £, and co2 difference between two combined usage metric objects, returning a new one' do
      a = CombinedUsageMetric.new(kwh: 10, £: 12, co2: 14)
      b = CombinedUsageMetric.new(kwh: 2, £: 2, co2: 2)

      new_combined_usage_metric = Usage::CombinedUsageMetricComparisonService.new(a, b).subtract
      expect(new_combined_usage_metric.kwh).to eq(8)
      expect(new_combined_usage_metric.£).to eq(10)
      expect(new_combined_usage_metric.co2).to eq(12)
    end
  end
end
