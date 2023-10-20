# frozen_string_literal: true

module Baseload
  class BaseloadCalculator
    def initialize(amr_data)
      @amr_data = amr_data
    end

    def self.for_meter(dashboard_meter)
      #return calculator cached by the amr data
      dashboard_meter.amr_data.baseload_calculator(dashboard_meter.sheffield_simulated_solar_pv_panels?)
    end

    # sheffield solar PV data artificially creates PV data which
    # is not always 100% consistent with real PV data e.g. if orientation is different
    # so the calculated statistics baseload can pick up morning and evening baseloads
    # lower than reality, resulting in volatile and less accurate baseload
    # test is on aggregate
    def self.calculator_for(amr_data, sheffield_solar_pv)
      #create a new calculator
      sheffield_solar_pv ? OvernightBaseloadCalculator.new(amr_data) : StatisticalBaseloadCalculator.new(amr_data)
    end

    def average_baseload_kw_date_range(date1 = up_to_1_year_ago, date2 = @amr_data.end_date)
      date_divisor = (date2 - date1 + 1)
      return 0.0 if date_divisor.zero?

      baseload_kwh_date_range(date1, date2) / date_divisor / 24.0
    end

    def baseload_kwh_date_range(date1, date2)
      total_kwh = 0.0
      (date1..date2).each do |date|
        total_kwh += baseload_kw(date)
      end
      total_kwh * 24.0
    end

    private

    def up_to_1_year_ago
      [end_date - 365, start_date].max
    end
  end
end
