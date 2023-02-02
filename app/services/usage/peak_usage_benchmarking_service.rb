# frozen_string_literal: true

module Usage
  class PeakUsageBenchmarkingService
    def initialize(meter_collection:, asof_date:)
      @meter_collection = meter_collection
      @asof_date = asof_date
    end

    def average_school_day_peak_usage_kw
      peak_kws.sum / peak_kws.length
    end

    private

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
