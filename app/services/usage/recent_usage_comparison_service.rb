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

    def calculate
      # # copied from AdviceRecentChangeBase
      # scalar = ScalarkWhCO2CostValues.new(@school)
      # @last_4_school_weeks_£_per_week     = scalar.aggregate_value({schoolweek: -3..0},  @fuel_type, :£) / 4.0
      # @previous_4_school_weeks_£_per_week = scalar.aggregate_value({schoolweek: -7..-4}, @fuel_type, :£) / 4.0
      # @difference_per_week_£ = @last_4_school_weeks_£_per_week - @previous_4_school_weeks_£_per_week

      # @last_4_school_weeks_kwh_per_week     = scalar.aggregate_value({schoolweek: -3..0},  @fuel_type, :kwh) / 4.0
      # @previous_4_school_weeks_kwh_per_week = scalar.aggregate_value({schoolweek: -7..-4}, @fuel_type, :kwh) / 4.0
      # @difference_per_week_kwh = @last_4_school_weeks_kwh_per_week - @previous_4_school_weeks_kwh_per_week

      # @percentage_change = percent_change(@previous_4_school_weeks_kwh_per_week, @last_4_school_weeks_kwh_per_week)

      # @rating = calculate_rating_from_range(-0.1, 0.1, @percentage_change)

      # @prefix_1 = @difference_per_week_£ > 0 ? 'up' : 'down'
      # @prefix_2 = @difference_per_week_£ > 0 ? 'increase' : 'reduction'
      # @summary = summary_text
    end

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
