# frozen_string_literal: true

module Usage
  class RecentUsagePeriodCalculationService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def recent_usage(date_range:)
      OpenStruct.new(
        date_range: [date_range.first, date_range.last],
        combined_usage_metric: combined_usage_metric_for(date_range)
      )
    end

    private

    def combined_usage_metric_for(date_range)
      CombinedUsageMetric.new(
        £: scalar.aggregate_value({ daterange: date_range }, @fuel_type, :£),
        kwh: scalar.aggregate_value({ daterange: date_range },  @fuel_type, :kwh),
        co2: scalar.aggregate_value({ daterange: date_range },  @fuel_type, :co2)
      )
    end

    def scalar
      # modified from AdviceRecentChangeBase
      @scalar = ScalarkWhCO2CostValues.new(@meter_collection)
    end
  end
end
