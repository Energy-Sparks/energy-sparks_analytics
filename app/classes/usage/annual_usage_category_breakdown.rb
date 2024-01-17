# frozen_string_literal: true

require_relative './usage_breakdown'

module Usage
  class AnnualUsageCategoryBreakdown < UsageBreakdown
    def potential_savings(versus: :exemplar_school)
      case versus
      when :exemplar_school
        CombinedUsageMetric.new(
          kwh: potential_saving_kwh_exemplar,
          £: potential_saving_£_exemplar,
          percent: percent_improvement_to_exemplar
        )
      when :benchmark_school
        CombinedUsageMetric.new(
          kwh: potential_saving_kwh_benchmark,
          £: potential_saving_£_benchmark,
          percent: percent_improvement_to_benchmark
        )
      else
        raise 'Invalid comparison'
      end
    end

    private

    def total_annual_£
      holiday.£ +
        weekend.£ +
        school_day_open.£ +
        school_day_closed.£ +
        community.£
    end

    def potential_saving_kwh_exemplar
      total_annual_kwh * percent_improvement_to_exemplar
    end

    def potential_saving_kwh_benchmark
      total_annual_kwh * percent_improvement_to_benchmark
    end

    def potential_saving_£_exemplar
      # Code adapted from AlertOutOfHoursBaseUsage#calculate
      total_annual_£ * percent_improvement_to_exemplar
    end

    def potential_saving_£_benchmark
      total_annual_£ * percent_improvement_to_benchmark
    end

    def total_annual_co2
      @holiday.co2 + @weekend.co2 + @school_day_open.co2 + @school_day_closed.co2 + @community.co2
    end

    def total_annual_kwh
      @holiday.kwh + @weekend.kwh + @school_day_open.kwh + @school_day_closed.kwh + @community.kwh
    end

    def percent_improvement_to_exemplar
      # Code adapted from AlertOutOfHoursBaseUsage#calculate
      [out_of_hours.percent - exemplar_out_of_hours_use_percent, 0.0].max
    end

    def percent_improvement_to_benchmark
      [out_of_hours.percent - benchmark_out_of_hours_use_percent, 0.0].max
    end

    def benchmark_out_of_hours_use_percent
      case @fuel_type
      when :electricity then BenchmarkMetrics::BENCHMARK_OUT_OF_HOURS_USE_PERCENT_ELECTRICITY
      when :gas then BenchmarkMetrics::BENCHMARK_OUT_OF_HOURS_USE_PERCENT_GAS
      when :storage_heater then BenchmarkMetrics::BENCHMARK_OUT_OF_HOURS_USE_PERCENT_STORAGE_HEATER
      end
    end

    def exemplar_out_of_hours_use_percent
      case @fuel_type
      when :electricity then BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_ELECTRICITY
      when :gas then BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_GAS
      when :storage_heater then BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_STORAGE_HEATER
      end
    end
  end
end
