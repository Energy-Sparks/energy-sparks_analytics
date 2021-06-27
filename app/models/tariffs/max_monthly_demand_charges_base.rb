class MaxMonthlyDemandChargesBase
  def initialize(amr_data, tariff)
    @amr_data = amr_data
    @tariff = tariff
    @month_max_demand_kw_cache = {}
  end
  
  def max_demand_for_month_kw(date, amr_data)
    start_of_month = DateTimeHelper.first_day_of_month(date)
    end_of_month = DateTimeHelper.last_day_of_month(date)
    @month_max_demand_kw_cache[start_of_month] ||= calculate_max_demand_kw(amr_data, start_of_month, end_of_month)
  end

  def calculate_max_demand_kw(amr_data, start_of_month, end_of_month)
    (start_of_month..end_of_month).to_a.map { |date| amr_data.peak_kw(date) }.max
  end
end