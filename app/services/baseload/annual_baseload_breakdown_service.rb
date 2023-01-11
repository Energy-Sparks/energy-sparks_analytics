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
          average_annual_co2_emissions: average_annual_co2_emissions_for(average_baseload_kw)
          # is_full_year?
        )
      end
    end

    def average_annual_co2_emissions_for(average_baseload_kw)
      # TODO: Need to finalise a way of calculating average annual co2 emissions for a given meter
      nil
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

    def year_range
      @year_range ||= (@aggregated_electricity_meters.amr_data.start_date.year..@aggregated_electricity_meters.amr_data.end_date.year).to_a
    end
  end
end
