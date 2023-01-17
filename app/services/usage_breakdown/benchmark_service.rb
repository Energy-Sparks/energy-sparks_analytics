# frozen_string_literal: true

module UsageBreakdown
  class BenchmarkService
    # Day type breakdowns are unavailable for storage_heater, storage_heaters, & solar_pv
    VALID_FUEL_TYPES = %i[electricity gas].freeze
    def initialize(school:, fuel_type:)
      raise 'Invalid fuel type' unless VALID_FUEL_TYPES.include?(fuel_type)

      @school = school
      @fuel_type = fuel_type
    end

    def school_day_type_breakdown
      @day_type_breakdown ||= UsageBreakdown::DayTypeBreakdown.new(school: @school, fuel_type: @fuel_type)
    end

    def potential_saving_kwh       #(compare: :benchmark_school)
      school_day_type_breakdown.total_annual_kwh * percent_improvement_to_exemplar
    end

    def potential_saving_pound_sterling          #(compare: :benchmark_school)
      # Code adapted from AlertOutOfHoursBaseUsage#calculate - @potential_saving_£ = @potential_saving_kwh * @fuel_cost_current
      school_day_type_breakdown.total_annual_pounds_sterling * percent_improvement_to_exemplar
    end

    def percent_improvement_to_exemplar
      # # Code adapted from AlertOutOfHoursBaseUsage#calculate - @percent_improvement_to_exemplar = [out_of_hours_percent - good_out_of_hours_use_percent, 0.0].max
      [school_day_type_breakdown.out_of_hours_percent - good_out_of_hours_use_percent, 0.0].max
    end

    def good_out_of_hours_use_percent
      # AlertOutOfHoursElectricityUsage#good_out_of_hours_use_percent = 0.35
      # AlertOutOfHoursGasUsage#good_out_of_hours_use_percent = 0.3
      @good_out_of_hours_use_percent ||= case @fuel_type
                                         when :electricity then BenchmarkMetrics::GOOD_OUT_OF_HOURS_USE_PERCENT_ELECTRICITY
                                         when :gas then BenchmarkMetrics::GOOD_OUT_OF_HOURS_USE_PERCENT_GAS
                                         end
    end    
  end
end
