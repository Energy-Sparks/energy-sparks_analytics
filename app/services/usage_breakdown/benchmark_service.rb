module UsageBreakdown
  class BenchmarkService
    def initialize(meter_collection:, fuel_type:)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
    end

    def out_of_hours_usage_comparison(compare: :benchmark_school)
      # CombinedUsageMetric.new() <- return values for benchmark school 
    end

    def estimated_savings(compare: :benchmark_school)
      # do_comparisons_here
      # case compare
      # when exemplar_school 
      # when benchmark_school
      #   CombinedUsageMetric.new() <- return values for benchmark school 
    end

    def calculate
      # extract benchmarking methods from AlertOutOfHoursBaseUsage calculate method here
    end
  end
end
