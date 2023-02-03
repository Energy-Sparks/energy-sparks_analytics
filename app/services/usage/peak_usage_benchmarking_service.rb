# frozen_string_literal: true

module Usage
  class PeakUsageBenchmarkingService
    def initialize(meter_collection:, asof_date:)
      @meter_collection = meter_collection
      @asof_date = asof_date
    end

    def average_school_day_peak_usage_kw(compare: :benchmark_school)
      case compare
      when :benchmark_school
        ''
      when :exemplar_school
        ''
      else
        raise 'Invalid comparison'
      end
    end

    private

    # rubocop:disable Layout/LineLength
    def average_school_day_peak_usage_kw_for_meter_collection
      @average_school_day_peak_usage_kw_for_meter_collection ||= meter_collection_peak_usage_calculation.average_school_day_peak_usage_kw
    end
    # rubocop:enable Layout/LineLength

    def meter_collection_peak_usage_calculation
      Usage::PeakUsageCalculationService.new(
        meter_collection: meter_collection,
        asof_date: @asof_date
      )
    end
  end
end
