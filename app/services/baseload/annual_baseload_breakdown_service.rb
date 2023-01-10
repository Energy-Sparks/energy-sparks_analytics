# frozen_string_literal: true

module Baseload
  class AnnualBaseloadBreakdownService
    def initialize(meter_collection)
      @meter_collection = meter_collection
    end

    def annual_baseload_breakdowns
      @annual_baseload_breakdowns ||= calculate_annual_baseload_breakdowns
    end

    private

    def calculate_annual_baseload_breakdowns
      @meter_collection.electricity_meters.each_with_object([]) do |meter, annual_baseload_breakdowns|
        annual_baseload_breakdowns << {
          mpan_mprn: meter.mpan_mprn,
          year_averages: year_averages_for(meter)
        }
      end
    end

    def year_averages_for(meter)
      analysis = ElectricityBaseloadAnalysis.new(meter)
      year_range.each_with_object([]) do |year, year_averages|
        average_baseload_kw = average_baseload_kw_for(analysis, year)

        year_averages << {
          year: year,
          average_annual_baseload_kw: average_baseload_kw,
          average_annual_baseload_cost_in_pounds_sterling: average_annual_baseload_cost_in_pounds_sterling_for(analysis, year),
          average_annual_co2_emissions: average_annual_co2_emissions_for(average_baseload_kw)
        }
      end
    end

    def average_annual_co2_emissions_for(average_baseload_kw)
      average_baseload_kw ? average_baseload_kw * EnergyEquivalences::UK_ELECTRIC_GRID_CO2_KG_KWH : nil
    end

    def start_and_end_dates_for(year)
      [Date.parse("01-01-#{year}"), Date.parse("31-12-#{year}")]
    end

    def average_annual_baseload_cost_in_pounds_sterling_for(analysis, year)
      analysis.baseload_economic_cost_date_range_£(*start_and_end_dates_for(year), :£current)
    rescue StandardError
      nil
    end

    def average_baseload_kw_for(analysis, year)
      analysis.average_baseload_kw(*start_and_end_dates_for(year))
    rescue StandardError
      nil
    end

    def year_range
      @year_range ||= (@meter_collection.energysparks_start_date.year..Date.today.year).to_a
    end
  end
end
