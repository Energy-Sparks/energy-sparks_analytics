#======================== Meter Consolidaiton Opportunity ==============
require_relative 'alert_gas_model_base.rb'

class AlertMeterConsolidationOpportunityBase < AlertAnalysisBase
  attr_reader :capital_cost
  attr_reader :number_of_live_meters, :annual_total_standing_charge
  attr_reader :cost_of_consolidating_1_meter_£

  COST_OF_1_METER_CONSOLIDATION_£ = 1000.0

  def initialize(school, fuel_type)
    super(school, :meter_consolidation)
    @fuel_type = fuel_type
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
      units:  Integer
    },
    annual_total_standing_charge: {
      description: 'Annual total standing charge (£)',
      units:  :£
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

  def one_year_saving_£
    @one_year_saving_£
  end

  def ten_year_saving_£
    super
  end

  def payback_years
    super
  end

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
      _day_cost_x48, _night_cost_x48, standing_charge = MeterTariffs.accounting_tariff_x48(max_combined_date, meter.mpan_mprn, @fuel_type, Array.new(48, 0.0), @school.default_energy_purchaser)
      standing_charges[meter.mpan_mprn] = standing_charge.values.sum
    end
    standing_charges
  end

  protected def meters
    raise EnergySparksAbstractBaseClass, 'Unexpected call to AlertMeterConsolidationOpportinutyBase abstract base class method meters'
  end

  private def calculate(asof_date)
    @number_of_meters = 1
    @annual_total_standing_charge = daily_standing_charges_for_live_meters.values.sum * 365.0
    sorted_standing_charges = daily_standing_charges_for_live_meters.values.sort
    low_annual_saving = sorted_standing_charges.first * 365.0
    high_annual_saving = @annual_total_standing_charge - (sorted_standing_charges.first * 365.0)
    @one_year_saving_£ = Range.new(low_annual_saving, high_annual_saving)
    @capital_cost = Range.new(COST_OF_1_METER_CONSOLIDATION_£, COST_OF_1_METER_CONSOLIDATION_£ * (sorted_standing_charges.length - 1))
    @rating = number_of_live_meters <= 1 ? 10.0 : 0.0
  end

  def analyse_private(asof_date)
    calculate(asof_date)

    # temporary dummy text to maintain backwards compatibility
    @analysis_report.term = :longterm
    @analysis_report.summary, text =
      if @rating < 10
        [
          %q( There might be an opportunity to save costs through meter consolidation ),
          %q( 
            <p>
              Your annual standing charges for <%= number_of_live_meters %> meters is 
              <%= FormatEnergyUnit.format(:£, annual_total_standing_charge) %>.
              You can ask your energy company (or DNO) to combine meters into one which
              would reduce your standing charges in proportion to the number
              of meters, which could lead to a potential saving between
              <%= FormatEnergyUnit.format(:£, ten_year_saving_£.first) %>
              and <%= FormatEnergyUnit.format(:£, ten_year_saving_£.last) %>
              over 10 years. The cost of consolidating a meter can be as low as
              <%= FormatEnergyUnit.format(:£, cost_of_consolidating_1_meter_£) %>.
              Payback on the investment is potentially
              between <%= payback_years.first.round(1) %> and <%= payback_years.last.round(1) %> years.
            </p>
            <p> 
              The opportunity to consolidate meters depends a little
              on the location of the meters, and works better if they are in close
              proximity. However, if one of the meters is on a differential tariff
              (economy 7) and is just for storage heater heating then the consolidation
              might not be economically viable. Consolidating meters may also reduce a more
              detailed understanding of energy consumption in different buildings, however,
              non-mains connected sub meters can be cheaply installed if necessary with
              no standing charges.
            </p>
            ).gsub(/^  /, '')
          ]
      else
        [
          %q( You only have one meter for this fuel so there are no meter consolidation saving opportunities. ),
          ''
        ]
      end

    description1 = AlertDescriptionDetail.new(:text, ERB.new(text).result(binding))
    @analysis_report.add_detail(description1)
    @analysis_report.rating = 10.0
    @analysis_report.status = :good
  end
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

