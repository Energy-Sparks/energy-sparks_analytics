# frozen_string_literal: true

module Usage
  class RecentUsageComparisonService
    def initialize(meter_collection:, fuel_type:, date: Date.today, weeks_to_compare: 4)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
      @weeks_to_compare = weeks_to_compare
    end

    def recent_usage
      OpenStruct.new(
        last_school_weeks: last_school_weeks,
        previous_school_weeks: previous_school_weeks,
        recent_usage_comparison: recent_usage_comparison
      )
    end

    private

    def last_school_weeks
      OpenStruct.new(
        date_range: last_school_weeks_date_range,
        results: last_school_weeks_results
      )
    end

    def previous_school_weeks
      OpenStruct.new(
        date_range: previous_school_weeks_date_range,
        results: previous_school_weeks_results
      )
    end

    def recent_usage_comparison
      @recent_usage_comparison ||= calculate_recent_usage
    end

    def previous_school_weeks_date_range
      @previous_school_weeks_date_range ||= scalar.aggregation_configuration(
        { schoolweek: previous_range },
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end

    def last_school_weeks_date_range
      @last_school_weeks_date_range ||= scalar.aggregation_configuration(
        { schoolweek: last_range },
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end

    def last_range
      # e.g. for a @weeks_to_compare value of 4 this would return a range of (-3..0)
      Range.new(split_range.last.first, split_range.last.last)
    end

    def previous_range
      # e.g. for a @weeks_to_compare value of 4 this would return a range of (-7..-4)
      Range.new(split_range.first.first, split_range.first.last)
    end

    def split_range
      # Returns a split array to use for comparison ranges 
      # e.g. for @weeks_to_compare values 1 through 5, method would return:  
      # 1 => [[-1], [0]]
      # 2 => [[-3, -2], [-1, 0]]
      # 3 => [[-5, -4, -3], [-2, -1, 0]]
      # 4 => [[-7, -6, -5, -4], [-3, -2, -1, 0]]
      # 5 => [[-9, -8, -7, -6, -5], [-4, -3, -2, -1, 0]]
      @split_range ||= (-((@weeks_to_compare * 2) - 1)..0).to_a.each_slice(@weeks_to_compare).to_a
    end

    def previous_school_weeks_results
      @previous_school_weeks_results ||= CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :co2) / 4.0
      )
    end

    def last_school_weeks_results
      @last_school_weeks_results ||= CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: -3..0 }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: -3..0 },  @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: -3..0 },  @fuel_type, :co2) / 4.0
      )
    end

    def scalar
      # modified from AdviceRecentChangeBase
      @scalar = ScalarkWhCO2CostValues.new(@meter_collection)
    end

    def calculate_recent_usage
      Usage::CombinedUsageMetricComparison.new(
        last_school_weeks_results,
        previous_school_weeks_results
      ).compare
    end
  end
end
