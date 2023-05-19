require_relative '../utilities/half_hourly_data'
require_relative '../utilities/half_hourly_loader'

# HalfHourlyData
#  CostsBase
#    EconomicCosts
#      EconomicCostsParameterised
#        CurrentEconomicCostsParameterised
#    EconomicCostsPreAggregated
#        CurrentEconomicCostsPreAggregated
#    AccountingCosts
#      AccountingCostsParameterised
#      AccountingCostsPreAggregated

# maintain costs information in parallel to AMRData
# set of data per day: 48 x half hour costs, plus standing charges
# 2 derived classes for: economic costs, accounting costs
# economic costs are simpler, just a rate (or 2 if differential) - good for forecasting, education
# accounting costs, contain lots of standing charges
class CostsBase < HalfHourlyData
  attr_reader :meter, :fuel_type, :amr_data, :fuel_type
  attr_accessor :post_aggregation_state

  #@param Dashboard::Meter meter the meter whose costs this schedule describes
  def initialize(meter)
    super(:amr_data_accounting_tariff)
    @meter = meter
    @amr_data = meter.amr_data
    @fuel_type = meter.fuel_type
    @bill_component_types_internal = Hash.new(nil) # only interested in (quick access) to keys, so maintain as hash rather than array
    @post_aggregation_state = false
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
    cost_hh_£ = one_days_cost_data(date).rates_at_half_hour(halfhour_index)
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
    raise EnergySparksNotEnoughDataException, "Doing costs calculation for date #{date} meter start_date #{meter.amr_data.start_date}" if date < meter.amr_data.start_date
    kwh_x48 = meter.amr_data.days_kwh_x48(date, :kwh)
    c = costs(tariff_date(date), meter, kwh_x48)
    return nil if c.nil?
    one_day_cost = OneDaysCostData.new(c)
    one_day_cost
  end

  public def calculate_x48_kwh_cost(date, kwh_x48)
    c = costs(date, meter, kwh_x48)
    raise EnergySparksUnexpectedStateException, "x48 cost for #{date}" if c.nil?
    OneDaysCostData.new(c).one_day_total_cost
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

  private def tariff_date(date)
    date
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
    !self[date].nil?
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
