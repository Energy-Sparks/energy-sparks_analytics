# frozen_string_literal: true

module Baseload
  class BaseloadPeriodComparisonService < BaseService
    def initialize(meter_collection:, fuel_type:, date: Date.today)
      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @date = date
    end

    def create_model
      OpenStruct.new(
        current_period_start_date: current_period_start_date,
        current_period_kwh: nil,
        current_period_co2: nil,
        current_period_gbp: nil,
        previous_period_start_date: previous_period_start_date,
        previous_period_kwh: nil,
        previous_period_co2: nil,
        previous_period_gbp: nil,
        abs_difference_gbp: abs_difference_gbp,
        abs_difference_co2: abs_difference_co2
      )
    end

    private

    def current_period_start_date
      @current_period_start_date ||= @date.last_week.beginning_of_week
    end

    def previous_period_start_date
      @previous_period_start_date ||= current_period_start_date.last_week.beginning_of_week
    end

    def current_period_gbp
      # current gbp code goes here
      0
    end

    def previous_period_gbp
      # previous gbp code goes here
      0
    end

    def current_period_co2
      0
    end

    def previous_period_co2
      0
    end

    def abs_difference_gbp
      (current_period_gbp - previous_period_gbp).abs
    end

    def abs_difference_co2
      (current_period_co2 - previous_period_co2).abs
    end

    def aggregate_meter
      @aggregate_meter ||= fuel_type == :electricity ? @school.aggregated_electricity_meters : @school.aggregated_heat_meters
    end
  end
end
