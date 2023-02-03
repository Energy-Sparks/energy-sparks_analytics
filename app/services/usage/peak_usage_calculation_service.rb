# frozen_string_literal: true

module Usage
  class PeakUsageCalculationService
    def initialize(meter_collection:, asof_date:)
      @meter_collection = meter_collection
      @asof_date = asof_date
    end

    def calculate_peak_usage
      OpenStruct.new(
        average_school_day_last_year_kw: average_school_day_last_year_kw,
        average_school_day_last_year_kw_per_pupil: average_school_day_last_year_kw_per_pupil,
        average_school_day_last_year_kw_per_floor_area: average_school_day_last_year_kw_per_floor_area
      )
    end

    private

    def average_school_day_last_year_kw
      @average_school_day_last_year_kw ||= peak_kws.sum / peak_kws.length
    end

    def average_school_day_last_year_kw_per_pupil
      @average_school_day_last_year_kw_per_pupil ||= average_school_day_last_year_kw / pupils
    end

    def average_school_day_last_year_kw_per_floor_area
      @average_school_day_last_year_kw_per_floor_area ||= average_school_day_last_year_kw / floor_area
    end

    def floor_area
      aggregated_electricity_meters.meter_floor_area(@meter_collection, start_date, end_date)
    end

    def pupils
      aggregated_electricity_meters.meter_number_of_pupils(@meter_collection, start_date, end_date)
    end

    def start_date
      @asof_date - 365
    end

    def end_date
      @asof_date
    end

    def peak_kws
      @peak_kws ||= calculate_peak_kws
    end

    def calculate_peak_kws
      date_range.each_with_object([]) do |date, peak_kws|
        next unless occupied?(date)

        peak_kws << aggregated_electricity_meters.amr_data.statistical_peak_kw(date)
      end
    end

    def holiday?(date)
      @meter_collection.holidays.holiday?(date)
    end

    def weekend?(date)
      date.saturday? || date.sunday?
    end

    def occupied?(date)
      !(weekend?(date) || holiday?(date))
    end

    def date_range
      start_date = [@asof_date - 364, aggregated_electricity_meters.amr_data.start_date].max
      start_date..@asof_date
    end

    def aggregated_electricity_meters
      @meter_collection.aggregated_electricity_meters
    end
  end
end
