# frozen_string_literal: true

module Baseload
  class AnnualBaseloadBreakdownService
    attr_reader :aggregated_electricity_meters

    def initialize(meter_collection)
      @aggregated_electricity_meters = meter_collection.aggregated_electricity_meters
      @analysis = ElectricityBaseloadAnalysis.new(@aggregated_electricity_meters)
    end

    def annual_baseload_breakdowns
      @annual_baseload_breakdowns ||= calculate_annual_baseload_breakdowns
    end

    private

    def calculate_annual_baseload_breakdowns
      year_range.each_with_object([]) do |year, breakdowns|
        average_baseload_kw = average_baseload_kw_for(year)

        breakdowns << Baseload::AnnualBaseloadBreakdown.new(
          year: year,
          average_annual_baseload_kw: average_baseload_kw,
          average_annual_baseload_cost_in_pounds_sterling: average_annual_baseload_cost_in_pounds_sterling_for(year),
          average_annual_baseload_kw_co2_emissions: average_annual_baseload_kw_co2_emissions(average_baseload_kw),
          meter_data_available_for_full_year: full_year_for?(year)
        )
      end
    end

    def full_year_for?(year)
      amr_data_start_and_end_date_range_covers?(Date.parse("01-01-#{year}")) &&
        amr_data_start_and_end_date_range_covers?(Date.parse("31-12-#{year}"))
    end

    def amr_data_start_and_end_date_range_covers?(date)
      date.between?(amr_data_start_date, amr_data_end_date)
    end

    def co2_per_kwh
      @co2_per_kwh ||= BlendedRateCalculator.new(@aggregated_electricity_meters).blended_co2_per_kwh
    end

    def average_annual_baseload_kw_co2_emissions(average_baseload_kw)
      return unless average_baseload_kw

      average_baseload_kw * co2_per_kwh
    end

    def start_and_end_dates_for(year)
      [Date.parse("01-01-#{year}"), Date.parse("31-12-#{year}")]
    end

    def average_annual_baseload_cost_in_pounds_sterling_for(year)
      @analysis.baseload_economic_cost_date_range_£(*start_and_end_dates_for(year), :£)
    rescue StandardError
      nil
    end

    def average_baseload_kw_for(year)
      @analysis.average_baseload_kw(*start_and_end_dates_for(year))
    rescue StandardError
      nil
    end

    def amr_data_start_date
      @amr_data_start_date ||= @aggregated_electricity_meters.amr_data.start_date
    end

    def amr_data_end_date
      @amr_data_end_date ||= @aggregated_electricity_meters.amr_data.end_date
    end

    def year_range
      @year_range ||= (amr_data_start_date.year..amr_data_end_date.year).to_a
    end
  end
end
