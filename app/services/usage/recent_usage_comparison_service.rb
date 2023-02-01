# frozen_string_literal: true

module Usage
  class RecentUsageComparisonService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def create_model; end

    private

    def current_period_start_date
      @current_period_start_date ||= @date.last_week.beginning_of_week
    end

    def previous_period_start_date
      @previous_period_start_date ||= current_period_start_date.last_week.beginning_of_week
    end

    def aggregate_meter
      @aggregate_meter ||= case fuel_type
                           when :electricity then @school.aggregated_electricity_meters
                           when :gas then @school.aggregated_heat_meters
                           end
    end
  end
end
