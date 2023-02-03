# frozen_string_literal: true

module Usage
  class PeakUsageBenchmarkingService
    def initialize(meter_collection:, asof_date:)
      @meter_collection = meter_collection
      @asof_date = asof_date
    end

    def average_peak_usage_kw(compare: :exemplar_school)
      case compare
      when :exemplar_school then average_school_day_peak_usage_kw - exemplar_kw
      # when :benchmark_school then nil
      else
        raise 'Invalid comparison'
      end
    end

    def estimated_savings(versus: :exemplar_school)
      case versus
      when :exemplar_school then consumption_above_exemplar_peak
      # when :benchmark_school then nil
      else
        raise 'Invalid comparison'
      end
    end

    private

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def consumption_above_exemplar_peak
      exemplar_kwh = exemplar_kw / 2.0

      totals = { kwh: 0.0, £: 0.0, co2: 0.0 }

      full_date_range.each do |date|
        (0..47).each do |hhi|
          kwh = aggregated_electricity_meters.amr_data.kwh(date, hhi, :kwh)
          percent_above_exemplar = capped_percent(kwh, exemplar_kwh)

          next if percent_above_exemplar.nil?

          totals[:kwh]  += percent_above_exemplar * kwh
          totals[:£]    += percent_above_exemplar * aggregated_electricity_meters.amr_data.kwh(date, hhi, :£current)
          totals[:co2]  += percent_above_exemplar * aggregated_electricity_meters.amr_data.kwh(date, hhi, :co2)
        end
      end

      totals = totals.transform_values { |v| scale_to_year(v) }

      CombinedUsageMetric.new(
        kwh: totals[:kwh],
        £: totals[:£],
        co2: totals[:co2]
      )
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def capped_percent(kwh, exemplar_kwh)
      return nil if kwh <= exemplar_kwh

      (kwh - exemplar_kwh) / kwh
    end

    def aggregated_electricity_meters
      @meter_collection.aggregated_electricity_meters
    end

    def full_date_range
      start_date = [@asof_date - 364, aggregated_electricity_meters.amr_data.start_date].max
      start_date..@asof_date
    end

    def scale_to_year(val)
      scale_factor = 365.0 / (full_date_range.last - full_date_range.first + 1)
      val * scale_factor
    end

    def benchmark_kw_m2
      BenchmarkMetrics::BENCHMARK_ELECTRICITY_PEAK_USAGE_KW_PER_M2
    end

    def exemplar_kw
      benchmark_kw_m2 * floor_area
    end

    def floor_area
      aggregated_electricity_meters.meter_floor_area(@meter_collection, start_date, end_date)
    end

    def start_date
      @asof_date - 365
    end

    def end_date
      @asof_date
    end

    def average_school_day_peak_usage_kw
      @average_school_day_peak_usage_kw ||= meter_collection_peak_usage_calculation.average_peak_kw
    end

    def meter_collection_peak_usage_calculation
      Usage::PeakUsageCalculationService.new(
        meter_collection: @meter_collection,
        asof_date: @asof_date
      )
    end
  end
end
