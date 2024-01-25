# frozen_string_literal: true

module Util
  class EnoughData
    def initialize(asof_date, aggregate_meter, days_required)
      @asof_date = asof_date
      @aggregate_meter = aggregate_meter
      @days_required = days_required
    end

    def enough_data?
      meter_data_checker.at_least_x_days_data?(@days_required)
    end

    def data_available_from
      meter_data_checker.date_when_enough_data_available(@days_required)
    end

    private

    def meter_data_checker
      @meter_data_checker ||= Util::MeterDateRangeChecker.new(@aggregate_meter, @asof_date)
    end
  end
end
