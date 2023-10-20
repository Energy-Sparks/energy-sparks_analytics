# frozen_string_literal: true

module Baseload
  # alternative heuristic for baseload calculation
  # find the average of the bottom 8 samples (4 hours) in a day
  class StatisticalBaseloadCalculator < BaseloadCalculator
    def baseload_kw(date, data_type = :kwh)
      statistical_baseload_kw(date, data_type)
    end

    private

    def statistical_baseload_kw(date, data_type = :kwh)
      @statistical_baseload_kw ||= {}
      @statistical_baseload_kw[data_type] ||= {}
      @statistical_baseload_kw[data_type][date] ||= calculate_statistical_baseload(date, data_type)
    end

    def calculate_statistical_baseload(date, data_type)
      days_data = @amr_data.days_kwh_x48(date, data_type) # 48 x 1/2 hour kWh
      sorted_kwh = days_data.clone.sort
      lowest_sorted_kwh = sorted_kwh[0..7]
      average_kwh = lowest_sorted_kwh.inject { |sum, el| sum + el }.to_f / lowest_sorted_kwh.size
      average_kwh * 2.0 # convert to kW
    end
  end
end
