# frozen_string_literal: true

module Usage
  class RecentUsageComparisonService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def create_model
      OpenStruct.new(
        last_4_school_weeks: last_4_school_weeks,
        previous_4_school_weeks: previous_4_school_weeks,
        recent_usage_comparison: recent_usage_comparison
      )
    end

    private

    def last_4_school_weeks
      OpenStruct.new(
        date_range: last_4_school_weeks_date_range,
        results: last_4_school_weeks_results
      )
    end

    def previous_4_school_weeks
      OpenStruct.new(
        date_range: previous_4_school_weeks_date_range,
        results: previous_4_school_weeks_results
      )
    end

    def recent_usage_comparison
      @recent_usage_comparison ||= calculate_recent_usage
    end

    def previous_4_school_weeks_date_range
      @previous_4_school_weeks_date_range ||= scalar.aggregation_configuration(
        { schoolweek: -7..-4 },
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end

    def last_4_school_weeks_date_range
      @last_4_school_weeks_date_range ||= scalar.aggregation_configuration(
        { schoolweek: -3..0 },
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end

    def previous_4_school_weeks_results
      @previous_4_school_weeks_results ||= CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :co2) / 4.0
      )
    end

    def last_4_school_weeks_results
      @last_4_school_weeks_results ||= CombinedUsageMetric.new(
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
      Usage::CombinedUsageMetricComparisonService.new(
        last_4_school_weeks_results,
        previous_4_school_weeks_results
      ).compare
    end
  end
end
