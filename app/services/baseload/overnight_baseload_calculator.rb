# frozen_string_literal: true

module Baseload
  # Alternative approach for calculating daily baseload
  #
  # Assumes that the school is using minimal power for other purposes during the
  # late evrning, between 8.30pm and midnight. The correspond to half-hourly periods
  # 41 through to 47.
  #
  # This approach is used where we are using modelled solar data from Sheffield, as there
  # are issues with the modelling that causes the early morning generation to be under-estimated,
  # e.g. if solar panels have different orientation. This results in the baseload being
  # underestimated. The evening periods will not suffer from this same problem.
  #
  # Sampling in the early morning instead is problematic as other consumers startup
  # (e.g. boiler pumps, often from around 01:00).
  class OvernightBaseloadCalculator < BaseloadCalculator
    def baseload_kw(date, data_type = :kwh)
      overnight_baseload_kw(date, data_type)
    end

    # Calculates the average baseload in kw between two dates
    def average_overnight_baseload_kw_date_range(date1 = start_date, date2 = end_date)
      overnight_baseload_kw_date_range(date1, date2) / (date2 - date1 + 1)
    end

    private

    def overnight_baseload_kw(date, data_type = :kwh)
      raise EnergySparksNotEnoughDataException, "Missing electric data for #{date}" if @amr_data.date_missing?(date)
      baseload_kw_between_half_hour_indices(date, 41, 47, data_type)
    end

    def baseload_kw_between_half_hour_indices(date, hhi1, hhi2, data_type = :kwh)
      total_kwh = 0.0
      count = 0
      if hhi2 > hhi1 # same day
        (hhi1..hhi2).each do |halfhour_index|
          total_kwh += @amr_data.kwh(date, halfhour_index, data_type)
          count += 1
        end
      else
        (hhi1..48).each do |halfhour_index| # before midnight
          total_kwh += @amr_data.kwh(date, halfhour_index, data_type)
          count += 1
        end
        (0..hhi2).each do |halfhour_index| # after midnight
          total_kwh += @amr_data.kwh(date, halfhour_index, data_type)
          count += 1
        end
      end
      #convert to kW and produce average
      total_kwh * 2.0 / count
    end

    def overnight_baseload_kw_date_range(date1, date2)
      total = 0.0
      (date1..date2).each do |date|
        total += overnight_baseload_kw(date)
      end
      total
    end

  end
end
