require_relative '../half_hourly_data'
require_relative '../half_hourly_loader'

# maintain costs information in parallel to AMRData
# set of data per day: 48 x half hour costs, plus standing charges
# 2 derived classes for: economic costs, accounting costs
# economic costs are simpler, just a rate (or 2 if differential) - good for forecasting, education
# accounting costs, contain lots of standing charges
class CostsBase < HalfHourlyData
  attr_reader :meter, :fuel_type, :amr_data, :fuel_type
  attr_accessor :post_aggregation_state
  def initialize(meter)
    super(:amr_data_accounting_tariff)
    @meter = meter
    @amr_data = meter.amr_data
    @fuel_type = meter.fuel_type
    @bill_component_types_internal = Hash.new(nil) # only interested in (quick access) to keys, so maintain as hash rather than array
    @post_aggregation_state = false
    @calculated = {}
  end

  def bill_component_types
    @bill_component_types_internal.keys
  end

  # combine OneDaysCostData[] into single aggregate OneDaysCostData
  def self.combined_day_costs(costs)
    combined = {
      rates_x48:        merge_costs_x48(costs.map(&:all_costs_x48)),
      standing_charges: combined_standing_charges(costs),
      differential:     costs.any?{ |c| c.differential_tariff? },
      system_wide:      combined_system_wide(costs),
      default:          combined_default(costs),
      tariff:           costs.map { |c| c.tariff }
    }

    OneDaysCostData.new(combined)
  end

  def self.combined_system_wide(costs)
    return true  if costs.all? { |c| c.system_wide == true }
    return false if costs.all? { |c| c.system_wide != true }
    :mixed
  end

  def self.combined_default(costs)
    return true  if costs.all? { |c| c.default == true }
    return false if costs.all? { |c| c.default != true }
    :mixed
  end

  # merge array of hashes of x48 costs
  def self.merge_costs_x48(arr_of_type_to_costs_x48)
    totals_x48_by_type = Hash.new{ |h, k| h[k] = [] }

    arr_of_type_to_costs_x48.each do |type_to_costs_x48|
      type_to_costs_x48.each do |type, c_x48|
        totals_x48_by_type[type].push(c_x48)
      end
    end

    totals_x48_by_type.transform_values{ |c_x48_array| AMRData.fast_add_multiple_x48_x_x48(c_x48_array) }
  end

  def self.combined_standing_charges(costs)
    combined_standing_charges = Hash.new(0.0)
    costs.each do |cost|
      cost.standing_charges.each do |type, value|
        combined_standing_charges[type] += value
      end
    end
    combined_standing_charges
  end

  # used in obscure case where we have split storage heater meter up
  # into storage and not-storage components, artificially split up standing charges
  # proportion by kwh total usage
  def scale_standing_charges(percent)
    (start_date..end_date).each do |date|
      one_days_cost_data(date).scale_standing_charges(percent)
    end
  end

  class OneDaysCostData
    attr_reader :standing_charges, :total_standing_charge, :one_day_total_cost
    attr_reader :bill_components, :bill_component_costs_per_day
    attr_reader :all_costs_x48
    # these could be true, false or :mixed
    attr_reader :system_wide, :default
    # either a single tariff, or an array for combined meters
    attr_reader :tariff

    def initialize(costs)
      @all_costs_x48    = costs[:rates_x48]
      @standing_charges = costs[:standing_charges]
      @differential     = costs[:differential]
      @system_wide      = costs[:system_wide]
      @default          = costs[:default]
      @tariff           = costs[:tariff]

      @total_standing_charge = standing_charges.empty? ? 0.0 : standing_charges.values.sum
      @one_day_total_cost = total_x48_costs + @total_standing_charge
      calculate_day_bill_components
    end
    
    def costs_x48
      @costs_x48 ||= AMRData.fast_add_multiple_x48_x_x48(@all_costs_x48.values)
    end

    def total_x48_costs
      @total_x48_costs ||= costs_x48.sum
    end

    def cost_x48(type)
      @all_costs_x48[type]
    end

    def differential_tariff?
      @differential
    end

    def rates_at_half_hour(halfhour_index)
      @all_costs_x48.map { |type, £_x48| [type, £_x48[halfhour_index]] }.to_h
    end

    # used for storage heater disaggregation
    def scale_standing_charges(percent)
      @standing_charges = @standing_charges.transform_values { |value| value * percent }
      @one_day_total_cost -= @total_standing_charge * (1.0 - percent)
      @total_standing_charge *= percent
      @bill_component_costs_per_day.merge!(@standing_charges)
    end

    private

    def calculate_day_bill_components
      @bill_component_costs_per_day = @all_costs_x48.transform_values{ |£_x48| £_x48.sum }
      @bill_component_costs_per_day.merge!(standing_charges)
      @bill_components = @bill_component_costs_per_day.keys
    end
  end

  def bill_component_costs_for_day(date)
    one_days_cost_data(date).bill_component_costs_per_day
  end

  def one_day_total_cost(date)
    one_days_cost_data(date).one_day_total_cost
  end

  def differential_tariff?(date)
    one_days_cost_data(date).differential_tariff?
  end

  def days_cost_data_x48(date)
    one_days_cost_data(date).costs_x48
  end

  def cost_data_halfhour(date, halfhour_index)
    one_days_cost_data(date).costs_x48[halfhour_index]
  end

  def cost_data_halfhour_broken_down(date, halfhour_index)
    cost_hh_£ = rates_at_half_hour(halfhour_index)
    cost_hh_£.merge!(one_days_cost_data(date).standing_charges.transform_values{ |one_day_kwh| one_day_kwh / 48.0 })
    cost_hh_£
  end

  public def calculate_tariff(meter)
    (amr_data.start_date..amr_data.end_date).each do |date|
      one_day_cost = calculate_tariff_for_date(date, meter)
      add(date, one_day_cost)
    end
    logger.info "Created #{costs_summary}"
  end

  public def calculate_tariff_for_date(date, meter)
    kwh_x48 = meter.amr_data.days_kwh_x48(date, :kwh)
    c = costs(date, meter, kwh_x48)
    return nil if c.nil?
    one_day_cost = OneDaysCostData.new(c)
    one_day_cost
  end

  public def costs_summary
    type_info = "with the following bill components: #{bill_component_types}"
    "costs for meter #{meter.mpan_mprn}, #{self.length} days from #{start_date} to #{end_date}, £#{total_costs.round(0)} of which standing charges £#{total_standing_charges.round(0)}, #{type_info}"
  end

  public def total_costs
    total_in_period(start_date, end_date)
  end

  private def total_standing_charges
    total_standing_charges_between_dates(start_date, end_date)
  end

  public def total_standing_charges_between_dates(date1, date2)
    total = 0.0
    (date1..date2).each do |date|
      total += one_days_cost_data(date).total_standing_charge
    end
    total
  end

  private def add_to_list_of_bill_component_types(one_day_cost)
    @bill_component_types_internal.merge!(Hash[one_day_cost.bill_components.collect { |type| [type, nil] }])
  end

  public def add(date, costs)
    set_min_max_date(date)
    add_to_list_of_bill_component_types(costs) unless costs.nil?
    self[date] = costs
  end

  def calculated?(date)
    @calculated[date] == true
  end

  def date_exists?(date)
    !date_missing?(date)
  end

  def date_missing?(date)
    c = one_days_cost_data(date)
    c.nil?
  end

  private def total_in_period(start_date, end_date)
    total = 0.0
    (start_date..end_date).each do |date|
      total += one_day_total_cost(date)
    end
    total
  end

  protected def costs(_date, _meter, _days_kwh_x48)
    raise EnergySparksAbstractBaseClass.new('Unexpected call to abstract base class for CostsBase: costs')
  end
end

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
end

# parameterised representation of economic costs until after agggregation to reduce memory footprint
class EconomicCostsParameterised < EconomicCosts

  def self.create_costs(meter)
    EconomicCostsParameterised.new(meter)
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
      combined_accounting_costs.add(date, combined_day_costs(list_of_days_accounting_costs))
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

  def self.create_costs(meter)
    AccountingCostsParameterised.new(meter)
  end
end

class AccountingCostsPreAggregated < AccountingCosts
  # always precalculated so don't calculate on the fly
  def one_days_cost_data(date)
    self[date]
  end

  def self.create_costs(meter)
    costs = AccountingCostsPreAggregated.new(meter)
    costs.calculate_tariff(amr_data, fuel_type, default_energy_purchaser)
    costs
  end
end
