# frozen_string_literal: true

module Baseload
  class AnnualBaseloadBreakdownService
    def initialize(meter_collection)
      # validate_meter_collection(meter_collection)
      @meter_collection = meter_collection
      @year_range = find_year_range
    end

    def calculate_breakdowns
      @meter_collection.electricity_meters.each_with_object([]) do |meter, annual_baseload_breakdowns|
        annual_baseload_breakdowns << {
          mpan_mprn: meter.mpan_mprn,
          year_averages: year_averages_for(meter)
        }
      end
    end

    def year_averages_for(meter)
      analysis = ElectricityBaseloadAnalysis.new(meter)
      @year_range.each_with_object([]) do |year, year_calculations|
        year_calculations << {
          year: year,
          average_annual_baseload_kw: average_baseload_kw_for(analysis, *start_and_end_dates_for(year)),
          average_annual_baseload_cost_in_pounds_sterling: nil,
          average_annual_co2_emissions: nil
        }
      end
    end

    def start_and_end_dates_for(year)
      [Date.parse("01-01-#{year}"), Date.parse("31-12-#{year}")]
    end

    def average_baseload_kw_for(analysis, start_date, end_date)
      analysis.average_baseload_kw(start_date, end_date)
    rescue StandardError
      nil
    end

    def find_year_range
      (@meter_collection.energysparks_start_date.year..Date.today.year).to_a
    end
  end
end
