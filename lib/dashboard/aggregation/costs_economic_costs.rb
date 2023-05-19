class EconomicCosts < CostsBase
  protected def costs(date, meter, days_kwh_x48)
    meter.meter_tariffs.economic_cost(date, days_kwh_x48)
  end

  def self.combine_economic_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining economic costs from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"

    combined_economic_costs = EconomicCostsPreAggregated.new(combined_meter)

    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |m| date >= m.amr_data.start_date && date <= m.amr_data.end_date }
      list_of_days_economic_costs = list_of_meters_on_date.map { |m| m.amr_data.economic_tariff.one_days_cost_data(date) }
      combined_economic_costs.add(date, combined_day_costs(list_of_days_economic_costs))
    end

    Logging.logger.info "Created combined meter economic #{combined_economic_costs.costs_summary}"
    combined_economic_costs
  end

  # TODO(PH, 30Nov2022) merge into code above
  def self.combine_current_economic_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining current economic costs from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"

    combined_economic_costs = CurrentEconomicCostsPreAggregated.new(combined_meter)

    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |m| date >= m.amr_data.start_date && date <= m.amr_data.end_date }
      list_of_days_economic_costs = list_of_meters_on_date.map { |m| m.amr_data.current_economic_tariff.one_days_cost_data(date) }
      combined_economic_costs.add(date, combined_day_costs(list_of_days_economic_costs))
    end

    Logging.logger.info "Created current combined meter economic #{combined_economic_costs.costs_summary}"
    combined_economic_costs
  end
end

# parameterised representation of economic costs until after agggregation to reduce memory footprint
class EconomicCostsParameterised < EconomicCosts
  def self.create_costs(meter)
    self.new(meter)
  end

  # returns a x48 array of half hourly costs
  def one_days_cost_data(date)
    return calculate_tariff_for_date(date, meter) unless post_aggregation_state
    add(date, calculate_tariff_for_date(date, meter)) unless calculated?(date)
    self[date]
  end

  def one_day_total_cost(date)
    @cache_days_totals[date] = one_days_cost_data(date).one_day_total_cost unless @cache_days_totals.key?(date)
    @cache_days_totals[date]
  end
end

class CurrentEconomicCostsParameterised < EconomicCostsParameterised
  # for current economic tariffs, don't use time varying tariffs
  # but use the most recent tariff
  #
  # slightly problematic for testing if asof_date changed as
  # will only use latest tariff not asof_date tariff,
  # perhaps use an '@@asof_date || end_date' to pass down this far?
  #
  private def tariff_date(_date)
    meter.amr_data.end_date
  end
end

class EconomicCostsPreAggregated < EconomicCosts
  def one_day_total_cost(date)
    @cache_days_totals[date] = one_days_cost_data(date).one_day_total_cost unless @cache_days_totals.key?(date)
    @cache_days_totals[date]
  end

  def one_days_cost_data(date)
    self[date]
  end

  def self.create_costs(meter)
    costs = EconomicCostsPreAggregated.new(meter)
    costs.calculate_tariff unless parameterised
    costs
  end
end

class CurrentEconomicCostsPreAggregated < EconomicCostsPreAggregated
  def self.create_costs(meter)
    costs = CurrentEconomicCostsPreAggregated.new(meter)
    costs.calculate_tariff unless parameterised
    costs
  end
end
