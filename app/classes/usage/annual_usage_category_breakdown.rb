# frozen_string_literal: true

# rubocop:disable Metrics/ParameterLists, Naming/MethodName
module Usage
  class AnnualUsageCategoryBreakdown
    attr_reader :holidays, :school_day_closed, :school_day_open, :weekends, :out_of_hours, :community

    def initialize(
      holidays:,
      school_day_closed:,
      school_day_open:,
      weekends:,
      out_of_hours:,
      community:,
      fuel_type:
    )
      @holidays = holidays
      @school_day_closed = school_day_closed
      @school_day_open = school_day_open
      @weekends = weekends
      @out_of_hours = out_of_hours
      @community = community
      @fuel_type = fuel_type
    end

    def potential_saving_kwh
      total_annual_kwh * percent_improvement_to_exemplar
    end

    def total_annual_kwh
      @holidays.kwh + @weekends.kwh + @school_day_open.kwh + @school_day_closed.kwh + @community.kwh
    end

    def potential_saving_£
      # Code adapted from AlertOutOfHoursBaseUsage#calculate
      total_annual_£ * percent_improvement_to_exemplar
    end

    def total_annual_£
      holidays.£ +
        weekends.£ +
        school_day_open.£ +
        school_day_closed.£ +
        community.£
    end

    def total_annual_co2
      @holidays.co2 + @weekends.co2 + @school_day_open.co2 + @school_day_closed.co2 + @community.co2
    end

    def percent_improvement_to_exemplar
      # Code adapted from AlertOutOfHoursBaseUsage#calculate
      [out_of_hours.percent - exemplar_out_of_hours_use_percent, 0.0].max
    end

    def exemplar_out_of_hours_use_percent
      # Code adapted from:
      # AlertOutOfHoursElectricityUsage#good_out_of_hours_use_percent = 0.35
      # AlertOutOfHoursGasUsage#good_out_of_hours_use_percent = 0.3
      case @fuel_type
      when :electricity then BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_ELECTRICITY
      when :gas then BenchmarkMetrics::EXEMPLAR_OUT_OF_HOURS_USE_PERCENT_GAS
      end
    end
  end
end
# rubocop:enable Metrics/ParameterLists, Naming/MethodName
