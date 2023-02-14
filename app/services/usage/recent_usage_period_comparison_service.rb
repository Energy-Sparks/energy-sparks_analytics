# frozen_string_literal: true

module Usage
  class RecentUsagePeriodComparisonService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def recent_usage(period_range: -3..0)
      OpenStruct.new(
        date_range: date_range_for(period_range),
        results: results_for(period_range)
      )
    end

    private

    def results_for(period_range)
      CombinedUsageMetric.new(
        £: scalar.aggregate_value({ schoolweek: period_range }, @fuel_type, :£) / 4.0,
        kwh: scalar.aggregate_value({ schoolweek: period_range },  @fuel_type, :kwh) / 4.0,
        co2: scalar.aggregate_value({ schoolweek: period_range },  @fuel_type, :co2) / 4.0
      )
    end

    def scalar
      # modified from AdviceRecentChangeBase
      @scalar = ScalarkWhCO2CostValues.new(@meter_collection)
    end

    def date_range_for(period_range)
      scalar.aggregation_configuration(
        { schoolweek: period_range },
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end
  end
end
