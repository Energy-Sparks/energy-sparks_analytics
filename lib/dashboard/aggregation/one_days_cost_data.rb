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

  def to_s
    "OneDaysCostData: Tcost #{one_day_total_cost} skeys: #{standing_charges.empty? ? '' : standing_charges.keys.map(&:to_s).join(',')} scT: #{total_standing_charge&.round(0)}"
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
