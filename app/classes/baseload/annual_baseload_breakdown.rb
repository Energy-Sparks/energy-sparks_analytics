module Baseload
  # Provides access to results of a years baseload calculations for an
  # aggregated electricity meter
  class AnnualBaseloadBreakdown
    attr_reader :year, :average_annual_baseload_kw, :average_annual_baseload_cost_in_pounds_sterling, :average_annual_co2_emissions
    def initialize(year:, average_annual_baseload_kw:, average_annual_baseload_cost_in_pounds_sterling:, average_annual_co2_emissions:)
      @year = year
      @average_annual_baseload_kw = average_annual_baseload_kw
      @average_annual_baseload_cost_in_pounds_sterling = average_annual_baseload_cost_in_pounds_sterling
      @average_annual_co2_emissions = average_annual_co2_emissions
    end
  end
end
