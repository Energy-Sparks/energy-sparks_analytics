module UsageBreakdown
  class BenchmarkService
    VALID_FUEL_TYPES = [:electricity, :gas, :storage_heater, :storage_heaters, :solar_pv].freeze
    def initialize(school:, fuel_type:)
      fail 'Invalid fuel type' unless VALID_FUEL_TYPES.include?(fuel_type)
      @school = school
      @fuel_type = fuel_type
      @aggregated_meter_colection_for_fuel_type = find_aggregate_meter
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

    private

    # Duplicated from MeterCollection#aggregate_meter
    # TODO: move to a helper class
    def find_aggregate_meter
      case @fuel_type
      when :electricity
        @school.aggregated_electricity_meters
      when :gas
        @school.aggregated_heat_meters
      when :storage_heater, :storage_heaters
        @school.storage_heater_meter
      when :solar_pv
        @school.aggregated_electricity_meters.sub_meters[:generation]
      end
    end
  end
end
