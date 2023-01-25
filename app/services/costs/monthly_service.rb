module Costs
  class MonthlyService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def create_model
      # meter_monthly_costs
      {}
    end

    private

    def meter_monthly_costs
      ma = MeterMonthlyCostsAdvice.new(@school, meter)
      ma.two_year_monthly_comparison_table_html
    end
  end
end
