require_relative '../half_hourly_data'
require_relative '../half_hourly_loader'

# maintain costs information in parallel to AMRData
# set of data per day: 48 x half hour costs, plus standing charges
# 2 derived classes for: economic costs, accounting costs
# economic costs are simpler, just a rate (or 2 if differential) - good for forecasting, education
# accounting costs, contain lots of standing charges
class CostsBase < HalfHourlyData
  attr_reader :meter_id, :fuel_type
  def initialize(meter_id)
    super(:amr_data_accounting_tariff)
    @meter_id = meter_id
    @bill_component_types_internal = Hash.new(nil) # only interested in (quick access) to keys, so maintain as hash rather than array
  end

  def bill_component_types
    @bill_component_types_internal.keys
  end

  private_class_method def self.combined_day_costs(costs)
    day_time_costs  = costs.map { |cost| cost.daytime_cost_x48 }.compact
    combined_day_costs_x48 = day_time_costs.empty? ? nil : AMRData.fast_add_multiple_x48_x_x48(day_time_costs)
    nighttime_costs = costs.map { |cost| cost.nighttime_cost_x48 }.compact
    combined_night_costs_x48 = nighttime_costs.empty? ? nil : AMRData.fast_add_multiple_x48_x_x48(nighttime_costs)
    combined_standing_charges = Hash.new(0.0)
    costs.each do |cost|
      cost.standing_charges.each do |type, value|
        combined_standing_charges[type] += value
      end
    end
    OneDaysCostData.new(combined_day_costs_x48, combined_night_costs_x48, combined_standing_charges)
  end

  # used in obscure case where we have split storage heater meter up
  # into storage and not-storage components, artificially split up standing charges
  # proportion by kwh total usage
  def scale_standing_charges(percent)
    (start_date..end_date).each do |date|
      self[date].scale_standing_charges(percent)
    end
  end

  class OneDaysCostData
    attr_reader :costs_x48, :daytime_cost_x48, :nighttime_cost_x48
    attr_reader :standing_charges, :total_standing_charge, :one_day_total_cost
    attr_reader :bill_components, :bill_component_costs_per_day

    def initialize(daytime_cost_x48, nighttime_cost_x48, standing_charges)
      @daytime_cost_x48 = daytime_cost_x48
      @nighttime_cost_x48 = nighttime_cost_x48
      @costs_x48 = nighttime_cost_x48.nil? ? daytime_cost_x48 : AMRData.fast_add_x48_x_x48(daytime_cost_x48, nighttime_cost_x48)
      @standing_charges = standing_charges
      @total_standing_charge = standing_charges.empty? ? 0.0 : standing_charges.values.sum
      @one_day_total_cost = @costs_x48.sum + @total_standing_charge
      calculate_day_bill_components(daytime_cost_x48, nighttime_cost_x48, standing_charges)
    end

    # used for storage heater disaggregation
    def scale_standing_charges(percent)
      @standing_charges = @standing_charges.transform_values { |value| value * percent }
      @one_day_total_cost -= @total_standing_charge * (1.0 - percent)
      @total_standing_charge *= percent
      @bill_component_costs_per_day.merge!(@standing_charges)
    end

    private def calculate_day_bill_components(daytime_cost_x48, nighttime_cost_x48, standing_charges)
      @bill_component_costs_per_day = {}
      if nighttime_cost_x48.nil?
        @bill_component_costs_per_day[:rate] = daytime_cost_x48.sum
      else
        @bill_component_costs_per_day[:daytime_rate] = daytime_cost_x48.sum
        @bill_component_costs_per_day[:nighttime_rate] = nighttime_cost_x48.sum
      end
      @bill_component_costs_per_day.merge!(standing_charges)
      @bill_components = @bill_component_costs_per_day.keys
    end
  end

  def bill_component_costs_for_day(date)
    self[date].bill_component_costs_per_day
  end

  def one_day_total_cost(date)
    self[date].one_day_total_cost
  end

  def days_cost_data_x48(date)
    self[date].costs_x48
  end

  def cost_data_halfhour(date, halfhour_index)
    self[date].costs_x48[halfhour_index]
  end

  def cost_data_halfhour_broken_down(date, halfhour_index)
    results = {}
    if self[date].nighttime_cost_x48.nil?
      results[:rate] = cost_data_halfhour(date, halfhour_index)
    else
      results[:daytime_rate] = self[date].daytime_cost_x48[halfhour_index]
      results[:nighttime_rate] = self[date].nighttime_cost_x48[halfhour_index]
    end
    results.merge!(self[date].standing_charges.transform_values{ |one_day_kwh| one_day_kwh / 48.0 })
    results
  end

  # either flat_rate or grid_carbon is set, the other to nil
  public def calculate_tariff(amr_data, fuel_type, default_energy_purchaser)
    (amr_data.start_date..amr_data.end_date).each do |date|
      kwh_x48 = nil
      if amr_data.date_missing?(date) # TODO(PH, 7Apr2019) - bad Castle data for 2009, work out why validation not cleaning up
        logger.warn "Warning: missing amr data for #{date} using zero"
        kwh_x48 = Array.new(48, 0.0)
      else
        kwh_x48 = amr_data.days_kwh_x48(date, :kwh)
      end
      daytime_cost_x48, nighttime_cost_x48, standing_charges = costs(date, meter_id, fuel_type, kwh_x48, default_energy_purchaser)
      one_day_cost = OneDaysCostData.new(daytime_cost_x48, nighttime_cost_x48, standing_charges)
      add(date, one_day_cost)
    end
    logger.info "Created #{costs_summary}"
  end

  public def costs_summary
    type_info = "with the following bill components: #{bill_component_types}"
    "costs for meter #{meter_id}, #{self.length} days from #{start_date} to #{end_date}, £#{total_costs.round(0)} of which standing charges £#{total_standing_charges.round(0)}, #{type_info}"
  end

  public def total_costs
    total_in_period(start_date, end_date)
  end

  private def total_standing_charges
    total_standing_charges_between_dates(start_date, end_date)
  end

  private def total_standing_charges_between_dates(date1, date2)
    total = 0.0
    (start_date..end_date).each do |date|
      total += self[date].total_standing_charge
    end
    total
  end

  private def add_to_list_of_bill_component_types(one_day_cost)
    @bill_component_types_internal.merge!(Hash[one_day_cost.bill_components.collect { |type| [type, nil] }])
  end

  public def add(date, costs)
    set_min_max_date(date)
    add_to_list_of_bill_component_types(costs)
    self[date] = costs
  end

  private def total_in_period(start_date, end_date)
    total = 0.0
    (start_date..end_date).each do |date|
      total += one_day_total_cost(date)
    end
    total
  end

  protected def costs(_date, _meter_id, _fuel_type, _days_kwh_x48)
    raise EnergySparksAbstractBaseClass.new("Unexpected call to abstract base class for CostsBase")
  end
end

class EconomicCosts < CostsBase
  protected def costs(date, meter_id, fuel_type, days_kwh_x48, _default_energy_purchaser)
    MeterTariffs.economic_tariff_x48(date, meter_id, fuel_type, days_kwh_x48)
  end

  # has to be done using data not from parameterised calculation
  def self.combine_economic_costs_from_multiple_meters(combined_meter_id, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining economic costs from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"
    combined_economic_costs = EconomicCosts.new(combined_meter_id)
    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |meter| date >= meter.amr_data.start_date && date <= meter.amr_data.end_date }
      list_of_days_economic_costs = list_of_meters_on_date.map { |meter| meter.amr_data.economic_tariff.one_days_data_x48(date) }
      # ap(list_of_days_economic_costs.map { |cost| cost.bill_components }.flatten.uniq.join(';') )
      combined_economic_costs.add(date, combined_day_costs(list_of_days_economic_costs))
    end
    Logging.logger.info "Created combined meter economic #{combined_economic_costs.costs_summary}"
    combined_economic_costs
  end

  def self.create_costs(meter_id, amr_data, fuel_type, default_energy_purchaser)
    costs = EconomicCosts.new(meter_id)
    costs.calculate_tariff(amr_data, fuel_type, default_energy_purchaser)
    costs
  end
end

class AccountingCosts < CostsBase
  protected def costs(date, meter_id, fuel_type, days_kwh_x48, default_energy_purchaser)
    MeterTariffs.accounting_tariff_x48(date, meter_id, fuel_type, days_kwh_x48, default_energy_purchaser)
  end

  # has to be done using data not from parameterised calculation
  def self.combine_accounting_costs_from_multiple_meters(combined_meter_id, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining accounting costs from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"
    combined_accounting_costs = AccountingCosts.new(combined_meter_id)
    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |meter| date >= meter.amr_data.start_date && date <= meter.amr_data.end_date }
      list_of_days_accounting_costs = list_of_meters_on_date.map { |meter| meter.amr_data.accounting_tariff.one_days_data_x48(date) }
      combined_accounting_costs.add(date, combined_day_costs(list_of_days_accounting_costs))
    end
    Logging.logger.info "Created combined meter accounting #{combined_accounting_costs.costs_summary}"
    combined_accounting_costs
  end

  def self.create_costs(meter_id, amr_data, fuel_type, default_energy_purchaser)
    costs = AccountingCosts.new(meter_id)
    costs.calculate_tariff(amr_data, fuel_type, default_energy_purchaser)
    costs
  end
end
