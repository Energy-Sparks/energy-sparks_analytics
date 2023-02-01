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

    def recent_usage_comparison
      @recent_usage_comparison ||= calculate_recent_usage
    end

    def previous_4_school_weeks
      @previous_4_school_weeks ||= CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: -7..-4 }, @fuel_type, :co2) / 4.0
      )
    end

    def last_4_school_weeks
      @last_4_school_weeks ||= CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: -3..0 }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: -3..0 },  @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: -3..0 },  @fuel_type, :co2) / 4.0
      )
    end

    # def current_period_start_date
    #   @current_period_start_date ||= @date.last_week.beginning_of_week
    # end

    # def previous_period_start_date
    #   @previous_period_start_date ||= current_period_start_date.last_week.beginning_of_week
    # end

    def scalar
      # modified from AdviceRecentChangeBase
      @scalar = ScalarkWhCO2CostValues.new(@meter_collection)
    end

    def calculate_recent_usage
      Usage::CombinedUsageMetricComparisonService.new(last_4_school_weeks, previous_4_school_weeks).compare
      # recent_usage_comparison.percent = percent_change(previous_4_school_weeks.kwh, last_4_school_weeks.kwh)
    end

    # # Copied from ContentBase
    # def percent_change(old_value, new_value)
    #   return nil if old_value.nil? || new_value.nil?
    #   return 0.0 if !old_value.nan? && old_value == new_value # both 0.0 case

    #   (new_value - old_value) / old_value
    # end
  end
end
