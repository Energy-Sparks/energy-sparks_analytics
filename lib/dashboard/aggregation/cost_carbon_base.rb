# base class for cost and carbon data, to switch between parameterised and pre-calculated (aggregated) data
class CostCarbonCalculatedCachedBase < HalfHourlyData
  attr_reader :parameterised
  def initialize(type, parameterised = false)
    super(type)
    @parameterised = parameterised
  end

  def one_days_data_x48(date)
    if @@dontcachecalculatedco2costdata && parameterised
      if is_a?(CarbonEmissions)
        return calculate_emissions_for_date(date, amr_data.days_kwh_x48(date), flat_rate, grid_carbon_schedule)
      else
        return calculate_tariff_for_date(date, amr_data, fuel_type, default_energy_purchaser)
      end
    elsif parameterised && date_missing?(date)
      if is_a?(CarbonEmissions)
        add(date, calculate_emissions_for_date(date, amr_data.days_kwh_x48(date), flat_rate, grid_carbon_schedule))
      else
        add(date, calculate_tariff_for_date(date, amr_data, fuel_type, default_energy_purchaser))
      end
    end
    super(date)
  end

  def one_days_cost_data(date)
    one_days_data_x48(date)
  end

  def days_cost_data_x48(date)
    parameterised ? super(date) : AMRData.fast_multiply_x48_x_scalar(super(date), 1.0)
  end

  def co2_data_halfhour(date, halfhour_index)
    parameterised ? one_days_data_x48(date)[halfhour_index] : one_days_data_x48(date)[halfhour_index] * 1.0
  end

  def cost_data_halfhour(date, halfhour_index)
    parameterised ? super(date, halfhour_index) : super(date, halfhour_index) * 1.0
  end

  def one_day_total_cost(date)
    parameterised ? one_days_data_x48(date).sum : super(date)
  end

  # co2
  def one_day_total(date)
    if parameterised && !@cache_days_totals.key?(date)
      @cache_days_totals[date] = one_days_data_x48(date).sum
    end
    super(date)
  end
end
