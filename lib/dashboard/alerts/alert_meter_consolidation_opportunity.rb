#======================== Meter Consolidaiton Opportunity ==============
require_relative 'alert_gas_model_base.rb'

class AlertMeterConsolidationOpportunityBase < AlertAnalysisBase
  attr_reader :capital_cost
  attr_reader :number_of_live_meters, :annual_total_standing_charge
  attr_reader :cost_of_consolidating_1_meter_£, :high_annual_saving

  COST_OF_1_METER_CONSOLIDATION_£ = 1000.0

  def initialize(school, fuel_type)
    super(school, :meter_consolidation)
    @fuel_type = fuel_type
    @relevance = meters.length > 1 ? :relevant : :never_relevant
  end

  def self.template_variables
    specific = {'Meter Consolidation' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def timescale
    'timescale not relevant to alert'
  end

  def enough_data
    :enough
  end

  def maximum_alert_date
    Date.today
  end

  TEMPLATE_VARIABLES = {
    number_of_live_meters: {
      description: 'Number of meters of this fuel type (currently in use)',
      units:  Integer,
      benchmark_code: 'mets'
    },
    annual_total_standing_charge: {
      description: 'Annual total standing charge (£)',
      units:  :£
    },
    high_annual_saving: {
      description: 'maximum potential annual saving (£)',
      units:  :£,
      benchmark_code: 'sav£'
    },
    fuel_type: {
      description: 'Fuel type (electricity or gas, eventually solar, storage heaters)',
      units:  :symbol
    },
    cost_of_consolidating_1_meter_£: {
      description: 'Estimated cost of consolidating 1 meter if they are close together (£)',
      units:  :£
    }
  }

  def cost_of_consolidating_1_meter_£
    COST_OF_1_METER_CONSOLIDATION_£
  end

  protected def number_of_live_meters
    live_meters.length
  end

  protected def format(unit, value, format, in_table, level)
    FormatUnit.format(unit, value, format, true, in_table, unit == :£ ? :no_decimals : level)
  end

  protected def live_meters
    max_combined_date = aggregate_meter.amr_data.end_date
    meters.select { |meter| meter.amr_data.end_date >= max_combined_date }
  end

  private def daily_standing_charges_for_live_meters
    max_combined_date = aggregate_meter.amr_data.end_date
    standing_charges = {}
    live_meters.each do |meter|
      kwh_x48 = meter.amr_data.days_kwh_x48(max_combined_date)
      standing_charge = meter.meter_tariffs.accounting_tariff_for_date(max_combined_date).costs(max_combined_date, kwh_x48)[:standing_charges]
      # _day_cost_x48, _night_cost_x48, standing_charge = MeterTariffs.accounting_tariff_x48(max_combined_date, meter, Array.new(48, 0.0))
      standing_charges[meter.mpan_mprn] = standing_charge.values.sum
    end
    standing_charges
  end

  protected def meters
    raise EnergySparksAbstractBaseClass, 'Unexpected call to AlertMeterConsolidationOpportinutyBase abstract base class method meters'
  end

  private def calculate(asof_date)
    @annual_total_standing_charge = daily_standing_charges_for_live_meters.values.sum * 365.0
    sorted_standing_charges = daily_standing_charges_for_live_meters.values.sort
    low_annual_saving = sorted_standing_charges.first * 365.0
    @high_annual_saving = @annual_total_standing_charge - (sorted_standing_charges.first * 365.0)
    one_year_saving_£ = Range.new(low_annual_saving, @high_annual_saving)
    capital_cost = Range.new(COST_OF_1_METER_CONSOLIDATION_£, COST_OF_1_METER_CONSOLIDATION_£ * (sorted_standing_charges.length - 1))
    set_savings_capital_costs_payback(one_year_saving_£, capital_cost)
    @rating = number_of_live_meters <= 1 ? 10.0 : 0.0
  end
  alias_method :analyse_private, :calculate
end

class AlertElectricityMeterConsolidationOpportunity < AlertMeterConsolidationOpportunityBase
  def initialize(school)
    super(school, :electricity)
  end

  def needs_gas_data?
    false
  end

  def needs_electricity_data?
    true
  end

  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end

  private def meters
    @school.electricity_meters
  end
end

class AlertGasMeterConsolidationOpportunity < AlertMeterConsolidationOpportunityBase
  def initialize(school)
    super(school, :gas)
  end

  def needs_electricity_data?
    false
  end

  def needs_gas_data?
    true
  end

  protected def aggregate_meter
    @school.aggregated_heat_meters
  end

  private def meters
    @school.heat_meters
  end
end

