# frozen_string_literal: true

module Usage
  class RecentUsagePeriodCalculationService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def recent_usage(timescale)
      if timescale[:daterange]
        date_range = [timescale[:daterange].first, timescale[:daterange].last]
      elsif timescale[:schoolweek]
        date_range = schoolweek_date_range_for(timescale)
      else
        fail
      end

      OpenStruct.new(
        date_range: date_range,
        combined_usage_metric: combined_usage_metric_for(timescale)
      )
    end

    private

    def combined_usage_metric_for(timescale)
      CombinedUsageMetric.new(
        £: scalar.aggregate_value(timescale, @fuel_type, :£),
        kwh: scalar.aggregate_value(timescale,  @fuel_type, :kwh),
        co2: scalar.aggregate_value(timescale,  @fuel_type, :co2)
      )
    end

    def scalar
      # modified from AdviceRecentChangeBase
      @scalar = ScalarkWhCO2CostValues.new(@meter_collection)
    end

    def schoolweek_date_range_for(timescale)
      scalar.aggregation_configuration(
        timescale,
        @fuel_type,
        :£,
        nil,
        true
      ).last(2)
    end
  end
end
