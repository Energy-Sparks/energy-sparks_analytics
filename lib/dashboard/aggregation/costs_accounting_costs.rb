class AccountingCosts < CostsBase
  protected def costs(date, meter, days_kwh_x48)
    meter.meter_tariffs.accounting_cost(date, days_kwh_x48)
  end

  # similar to Economic version, but too many differences to easily refactor to inherited version for the moment
  def self.combine_accounting_costs_from_multiple_meters(combined_meter, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining accounting costs from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"

    combined_accounting_costs = AccountingCostsPreAggregated.new(combined_meter)

    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |m| date >= m.amr_data.start_date && date <= m.amr_data.end_date }.compact
      missing_accounting_costs = list_of_meters_on_date.select { |m| !m.amr_data.date_exists_by_type?(date, :accounting_cost) }
      # silently skip calculation
      next if missing_accounting_costs.length > 0
      list_of_days_accounting_costs = list_of_meters_on_date.map { |m| m.amr_data.accounting_tariff.one_days_cost_data(date) }
      combined_accounting_costs.add(date, OneDaysCostData.combine_costs(list_of_days_accounting_costs))
    end

    Logging.logger.info "Created combined meter accounting #{combined_accounting_costs.costs_summary}"
    combined_accounting_costs
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

class AccountingCostsParameterised < AccountingCosts
  # returns a x48 array of half hourly costs, only caches post aggregation, and front end cache
  def one_days_cost_data(date)
    return calculate_tariff_for_date(date, meter) unless post_aggregation_state
    add(date, calculate_tariff_for_date(date, meter)) unless calculated?(date)
    self[date]
  end

  # in the case of parameterised accounting costs, the underlying costs types are not known
  # until post aggregation, on the first request for chart bucket names which is before
  # data requests get made which build up the component list, so manually instantiate the list
  # on the fly; quicker alternative would be to search through the static tariff data through time (meter_tariffs)
  def bill_component_types
    create_all_bill_components(amr_data.start_date, amr_data.end_date) if post_aggregation_state && @bill_component_types_internal.empty?
    @bill_component_types_internal.keys
  end

  # also instantiates all accounting data in pre aggregated form
  private def create_all_bill_components(start_date, end_date)
    (start_date..end_date).each do |date|
      one_day_total_cost(date)
    end
  end

end

class AccountingCostsPreAggregated < AccountingCosts
  # always precalculated so don't calculate on the fly
  def one_days_cost_data(date)
    self[date]
  end
end
