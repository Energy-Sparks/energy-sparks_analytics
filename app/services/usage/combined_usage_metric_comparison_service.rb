# frozen_string_literal: true

module Usage
  class CombinedUsageMetricComparisonService
    def initialize(combined_usage_metric_a, combined_usage_metric_b)
      raise if combined_usage_metric_a.class != CombinedUsageMetric
      raise if combined_usage_metric_b.class != CombinedUsageMetric

      @combined_usage_metric_a = combined_usage_metric_a
      @combined_usage_metric_b = combined_usage_metric_b
    end

    def subtract
      CombinedUsageMetric.new(
        kwh: (@combined_usage_metric_a.kwh || 0) - (@combined_usage_metric_b.kwh || 0),
        £: (@combined_usage_metric_a.£ || 0) - (@combined_usage_metric_b.£ || 0),
        co2: (@combined_usage_metric_a.co2 || 0) - (@combined_usage_metric_b.co2 || 0)
      )
    end
  end
end
