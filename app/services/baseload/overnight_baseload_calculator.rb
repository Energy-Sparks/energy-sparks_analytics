# frozen_string_literal: true

module Baseload
  # sheffield solar PV data artificially creates PV data which
  # is not always 100% consistent with real PV data e.g. if orientation is different
  # so the calculated statistics baseload can pick up morning and evening baseloads
  # lower than reality, resulting in volatile and less accurate baseload
  # test is on aggregate
  class OvernightBaseloadCalculator < BaseloadCalculator
    def baseload_kw(date, data_type = :kwh)
      overnight_baseload_kw(date, data_type)
    end

    def average_overnight_baseload_kw_date_range(date1 = start_date, date2 = end_date)
      overnight_baseload_kwh_date_range(date1, date2) / (date2 - date1 + 1)
    end

    private

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
      total_kwh * 2.0 / count
    end

    def overnight_baseload_kwh_date_range(date1, date2)
      total = 0.0
      (date1..date2).each do |date|
        unless @amr_data.key?(date)
          raise EnergySparksNotEnoughDataException,
                "Missing electric data for #{date}"
        end

        total += overnight_baseload_kw(date)
      end
      total
    end

    def overnight_baseload_kw(date, data_type = :kwh)
      raise EnergySparksNotEnoughDataException, "Missing electric data (2) for #{date}" if @amr_data.date_missing?(date)

      # The values 41 and 47 represent the electricity consumed between 20:30 and midnight.
      # (i.e. 48 half hour values in a day so 41 * 0.5 = 20.5 => 20:30 in the evening to 47 * 0.5 => 23.5 => 23:30)
      # This time of day for schools with solar PV panels synthesized by Sheffield PV data
      # should provide a reasonable estimate of baseload.
      # Sampling in the early morning instead is problematic as other consumers startup
      # (e.g. boiler pumps, often from around 01:00).
      baseload_kw_between_half_hour_indices(date, 41, 47, data_type)
    end
  end
end
