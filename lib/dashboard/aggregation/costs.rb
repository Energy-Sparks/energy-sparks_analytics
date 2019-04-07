require_relative '../half_hourly_data'
require_relative '../half_hourly_loader'

# maintain costs information in parallel to AMRData
# set of data per day: 48 x half hour costs, plus standing charges
# 2 derived classes for: economic costs, accounting costs
# economic costs are simpler, just a rate (or 2 if differential) - good for forecasting, education
# accounting costs, contain lots of standing charges
class CostsBase < HalfHourlyData
  attr_reader :meter_id, :fuel_type
  def initialize(meter_id, amr_data, fuel_type, default_energy_purchaser)
    super(:amr_data_accounting_tariff)
    @meter_id = meter_id
    @fuel_type = fuel_type
    @default_energy_purchaser = default_energy_purchaser
    @bill_component_types_internal = Hash.new(nil) # only interested in (quick access) to keys, so maintain as hash rather than array
    calculate_tariff(amr_data)
  end

  def bill_component_types
    @bill_component_types_internal.keys
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
  private def calculate_tariff(amr_data)
    total_standing_charges = 0.0
    (amr_data.start_date..amr_data.end_date).each do |date|
      daytime_cost_x48, nighttime_cost_x48, standing_charges = costs(date, meter_id, @fuel_type, amr_data.days_kwh_x48(date, :kwh))
      one_day_cost = OneDaysCostData.new(daytime_cost_x48, nighttime_cost_x48, standing_charges)
      add_to_list_of_bill_component_types(one_day_cost)
      add(date, one_day_cost)
      total_standing_charges += one_day_cost.total_standing_charge
    end
    total_cost = total_in_period(start_date, end_date)
    info = "Created cost schedule for meter #{meter_id}, #{self.length} days from #{start_date} to #{end_date}, £#{total_cost.round(0)} standing £#{total_standing_charges.round(2)}"
    logger.info info
    puts info
    types = bill_component_types.join(',')
    type_info = "with the following bill components: #{types}"
    logger.info type_info
    puts type_info 
  end

  private def add_to_list_of_bill_component_types(one_day_cost)
    @bill_component_types_internal.merge!(Hash[one_day_cost.bill_components.collect { |type| [type, nil] }])
  end

  private def add(date, costs)
    set_min_max_date(date)
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
  protected def costs(date, meter_id, fuel_type, days_kwh_x48)
    MeterTariffs.economic_tariff_x48(date, meter_id, fuel_type, days_kwh_x48)
  end
end

class AccountingCosts < CostsBase
  protected def costs(date, meter_id, fuel_type, days_kwh_x48)
    MeterTariffs.accounting_tariff_x48(date, meter_id, fuel_type, days_kwh_x48, @default_energy_purchaser)
  end
end