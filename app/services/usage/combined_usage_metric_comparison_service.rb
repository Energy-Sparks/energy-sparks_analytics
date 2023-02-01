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
        co2: (@combined_usage_metric_a.co2 || 0) - (@combined_usage_metric_b.co2 || 0),
        percent: percent_change(@combined_usage_metric_a.percent, @combined_usage_metric_b.percent)
      )
    end

    private

    # Copied from ContentBase
    def percent_change(old_value, new_value)
      old_value = old_value.to_f
      new_value = new_value.to_f
      return nil if old_value.nil? || new_value.nil?
      return 0.0 if !old_value.nan? && old_value == new_value # both 0.0 case

      (new_value - old_value) / old_value
    end
  end
end
