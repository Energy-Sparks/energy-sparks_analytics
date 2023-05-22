class EconomicCosts < CostsBase
  protected def costs(date, meter, days_kwh_x48)
    meter.meter_tariffs.economic_cost(date, days_kwh_x48)
  end

  # Processes the tariff and consumption data for a list of meters, to calculate the combined costs which are them associated
  # with an aggregate meter
  #
  # @param Dashboard::Meter combined_meter the aggregate meter to which the combined costs will be added
  # @param Array list_of_meters the individual meters whose costs and tariffs will be processed
  # @param Date combined_start_date start date of range
  # @param Date combined_end_date end date of range
  # @return EconomicCostsPreAggregated
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
  #
  # Processes the tariff and consumption data for a list of meters, to calculate the combined costs which are them associated
  # with an aggregate meter
  #
  # @param Dashboard::Meter combined_meter the aggregate meter to which the combined economic costs will be added
  # @param Array list_of_meters the individual meters whose costs and tariffs will be processed
  # @param Date combined_start_date start date of range
  # @param Date combined_end_date end date of range
  # @return CurrentEconomicCostsPreAggregated
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

# Extends base class to implement caching of calculated costs.
#
# Pre-aggregation the costs are always calculated on demand. And are not added to the
# time series of costs maintained by the class. After aggregation they are calculated
# and stored. So the series is calculated and built on demand.
#
# "parameterised representation of economic costs until after agggregation to reduce memory footprint"
class EconomicCostsParameterised < EconomicCosts
  def self.create_costs(meter)
    self.new(meter)
  end

  # Returns the costs for a specific date
  # @param Date date
  # @return OneDaysCostData
  def one_days_cost_data(date)
    return calculate_tariff_for_date(date, meter) unless post_aggregation_state
    add(date, calculate_tariff_for_date(date, meter)) unless calculated?(date)
    self[date]
  end

  #Return total cost for a day.
  #See OneDaysCostData#one_day_total_cost
  #
  #Caches results, regardless of aggregation state
  def one_day_total_cost(date)
    @cache_days_totals[date] = one_days_cost_data(date).one_day_total_cost unless @cache_days_totals.key?(date)
    @cache_days_totals[date]
  end
end

# Extends the default economic costs class to force calculations to always
# use the tariff data for the latest meter date.
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

# This implementation relies on the one_days_cost_data having been explicitly
# added to the schedule of data, rather than being calculated (and possibly cached)
# on the fly. It's used where we are creating a schedule of costs for a combined
# meter and there are a variety of tariffs used by the underlying meters. Reduces
# the calculation overheads.
class EconomicCostsPreAggregated < EconomicCosts

  #Return total cost for a day.
  #See OneDaysCostData#one_day_total_cost
  #
  #Caches results, regardless of aggregation state
  def one_day_total_cost(date)
    @cache_days_totals[date] = one_days_cost_data(date).one_day_total_cost unless @cache_days_totals.key?(date)
    @cache_days_totals[date]
  end

  # Returns the costs for a specific date
  # Relies on costs having been pre-calculated and added to the schedule
  def one_days_cost_data(date)
    self[date]
  end

  #Unused? There is no parameterised variable or method
  def self.create_costs(meter)
    costs = EconomicCostsPreAggregated.new(meter)
    costs.calculate_tariff unless parameterised
    costs
  end
end

class CurrentEconomicCostsPreAggregated < EconomicCostsPreAggregated
  #Unused? There is no parameterised variable or method
  def self.create_costs(meter)
    costs = CurrentEconomicCostsPreAggregated.new(meter)
    costs.calculate_tariff unless parameterised
    costs
  end
end
