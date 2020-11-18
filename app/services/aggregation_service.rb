# This should take a meter collection and populate
# it with aggregated & validated data
require 'benchmark/memory'
class AggregateDataService
  include Logging
  include AggregationMixin

  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @heat_meters        = @meter_collection.heat_meters
    @electricity_meters = @meter_collection.electricity_meters
  end

  def validate_and_aggregate_meter_data
    logger.info 'Validating and Aggregating Meters'
    validate_meter_data
    aggregate_heat_and_electricity_meters

    # Return populated with aggregated data
    @meter_collection
  end

  # This is called by the EnergySparks codebase
  def validate_meter_data
    logger.info 'Validating Meters'
    validate_meter_list(@heat_meters)
    validate_meter_list(@electricity_meters)
  end

  # This is called by the EnergySparks codebase
  def aggregate_heat_and_electricity_meters
    logger.info 'Aggregate Meters'
    bm = Benchmark.realtime {
      set_long_gap_boundary_on_all_meters

      aggregate_heat_meters

      process_electricity_meters

      set_post_aggregation_state_on_all_meters
    }
    calc_text = "Calculated meter aggregation in #{bm.round(3)} seconds"
    logger.info calc_text
    puts calc_text
  end

  private

  private def process_electricity_meters
    create_unaltered_aggregate_electricity_meter_for_pv_and_storage_heaters

    process_solar_meters

    aggregate_electricity_meters

    disaggregate_storage_heaters if @meter_collection.storage_heaters?
    
    combine_solar_pv_submeters_into_aggregate if more_than_one_solar_pv_sub_meter?
  end

  def process_solar_meters
    if @meter_collection.solar_pv_panels?
      aggregate_solar = AggregateDataServiceSolar.new(@meter_collection)
      processed_meters = aggregate_solar.process_solar_pv_electricity_meters
      # assign references to arrays, as can't be asigned within AggregateDataServiceSolar
      @meter_collection.update_electricity_meters(processed_meters)
      @electricity_meters = processed_meters
    end
  end

  private def set_long_gap_boundary_on_all_meters
    @meter_collection.all_meters.each do |meter|
      meter.amr_data.set_long_gap_boundary
    end
  end

  def more_than_one_solar_pv_sub_meter?
    @meter_collection.solar_pv_panels? && @meter_collection.electricity_meters.length > 1
  end

  # allows parameterised carbon/cost objects to cache data post
  # aggregation, reducing memory footprint in front end cache prior to this
  # while maintaining charting performance once out of cache
  private def set_post_aggregation_state_on_all_meters
    @meter_collection.all_meters.each do |meter|
      meter.amr_data.set_post_aggregation_state
    end
  end

  private def validate_meter_list(list_of_meters)
    logger.info "Validating #{list_of_meters.length} meters"
    list_of_meters.each do |meter|
      validate_meter = ValidateAMRData.new(meter, 50, @meter_collection.holidays, @meter_collection.temperatures)
      validate_meter.validate
    end
  end

  def combine_solar_pv_submeters_into_aggregate
    aggregate_meter = @meter_collection.aggregated_electricity_meters
    aggregate_sub_meters_by_type(aggregate_meter, @meter_collection.electricity_meters)
=begin
    SolarPVPanels::SUBMETER_TYPES.each do |solar_sub_meter_type|
      meters_to_aggregate = @meter_collection.electricity_meters.map do |electric_meter|
        electric_meter.sub_meters.find{ |sub_meter| sub_meter.name == solar_sub_meter_type }
      end.compact
      next if meters_to_aggregate.empty? # defensive
      if meters_to_aggregate.length == 1
        aggregate_meter.sub_meters.push(meters_to_aggregate[0])
      else
        aggregated_sub_meter = aggregate_meters(nil, meters_to_aggregate, :electricity)
        aggregated_sub_meter.name = solar_sub_meter_type
        aggregate_meter.sub_meters.push(aggregated_sub_meter)
        # assign too many times
        aggregate_meter.id   = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
        aggregate_meter.name = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
      end
    end
=end
  end

  def aggregate_sub_meters_by_type(combined_meter, meters)
    sub_meter_types = meters.map{ |m| m.sub_meters.keys }.uniq

    sub_meters_grouped_by_type = sub_meter_types.map do |sub_meter_type|
      [
        sub_meter_type,
        meters.map{ |m| m.sub_meters[sub_meter_type] }
      ]
    end.to_h

    sub_meters_grouped_by_type.each do |sub_meter_type, sub_meters|
      combined_sub_meter = aggregate_meters(nil, sub_meters, sub_meters[0].fuel_type)
      combined_sub_meter.id   = sub_meters[0].id
      combined_sub_meter.name = sub_meters[0].name
      combined_meter.sub_meters[sub_meter_type] = combined_sub_meter
    end
  end

  # if an electricity meter is split up into a storage and non-storage version
  # we need to artificially split up the standing charges
  # in any account scenario these probably need re-aggregating for any bill
  # reconciliation if kept seperate for these purposes
  private def proportion_out_accounting_standing_charges(meter1, meter2)
    total_kwh_meter1 = meter1.amr_data.accounting_tariff.total_costs
    total_kwh_meter2 = meter2.amr_data.accounting_tariff.total_costs
    percent_meter1 = total_kwh_meter1 / (total_kwh_meter1 + total_kwh_meter2)
    meter1.amr_data.accounting_tariff.scale_standing_charges(percent_meter1)
    meter2.amr_data.accounting_tariff.scale_standing_charges(1.0 - percent_meter1)
  end

 
  private def lookup_synthetic_meter(type)
    meter_id = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, type)
    @meter_collection.meter?(meter_id, true)
  end

  def aggregate_heat_meters
    calculate_meters_carbon_emissions_and_costs(@heat_meters, :gas)
    @meter_collection.aggregated_heat_meters = aggregate_main_meters(@meter_collection.aggregated_heat_meters, @heat_meters, :gas)
  end

  def aggregate_electricity_meters
    calculate_meters_carbon_emissions_and_costs(@electricity_meters, :electricity)
    @meter_collection.aggregated_electricity_meters = aggregate_main_meters(@meter_collection.aggregated_electricity_meters, @electricity_meters, :electricity)
    assign_unaltered_electricity_meter(@meter_collection.aggregated_electricity_meters)
  end

  # pv and storage heater meters alter the meter data, but for
  # P&L purposes we need an unaltered copy of the original meter
  def create_unaltered_aggregate_electricity_meter_for_pv_and_storage_heaters
    if @meter_collection.solar_pv_panels? || @meter_collection.storage_heaters?
      calculate_meters_carbon_emissions_and_costs(@electricity_meters, :electricity)
      unaltered_aggregate_meter = aggregate_main_meters(nil, @electricity_meters, :electricity, true)
      assign_unaltered_electricity_meter(unaltered_aggregate_meter)
    end
  end

  def assign_unaltered_electricity_meter(meter)
    @meter_collection.unaltered_aggregated_electricity_meters ||= meter
  end

  private def combine_meter_meta_data(list_of_meters)
    meter_names = []
    ids = []
    floor_area = 0
    pupils = 0
    list_of_meters.each do |meter|
      meter_names.push(meter.name)
      ids.push(meter.id)
      if !floor_area.nil? && !meter.floor_area.nil?
        floor_area += meter.floor_area
      else
        floor_area = nil
      end
      if !pupils.nil? && !meter.number_of_pupils.nil?
        pupils += meter.number_of_pupils
      else
        pupils = nil
      end
    end
    name = meter_names.join(' + ')
    id = ids.join(' + ')
    [name, id, floor_area, pupils]
  end

  def aggregate_main_meters(combined_meter, list_of_meters, type, copy_amr_data = false)
    logger.info "Aggregating #{list_of_meters.length} meters and #{list_of_meters.map{ |sm| sm.sub_meters.length}.sum} sub meters"
    combined_meter = aggregate_meters(combined_meter, list_of_meters, type, copy_amr_data)
    # combine_sub_meters_deprecated(combined_meter, list_of_meters) # TODO(PH, 15Aug2019) - not sure about the history behind this call, perhaps simulator, but commented out for the moment
    combined_meter
  end

  # copy meter and amr data - for pv, storage heater meters about to be disaggregated
  private def copy_meter_and_amr_data(meter)
    logger.info "Creating cloned copy of meter #{meter.mpan_mprn}"
    new_meter = nil
    bm = Benchmark.realtime {
      new_meter = Dashboard::Meter.new(
        meter_collection: @meter_collection,
        amr_data:         AMRData.copy_amr_data(meter.amr_data),
        type:             meter.fuel_type,
        identifier:       meter.mpan_mprn,
        name:             meter.name,
        floor_area:       meter.floor_area,
        number_of_pupils: meter.number_of_pupils,
        meter_attributes: meter.meter_attributes
      )
      calculate_meter_carbon_emissions_and_costs(new_meter, :electricity)
      new_meter.amr_data.set_post_aggregation_state
    }
    calc_text = "Copied meter and amr data in #{bm.round(3)} seconds"
    logger.info calc_text
    puts calc_text
    new_meter
  end

  private def aggregate_meters(combined_meter, list_of_meters, fuel_type, copy_amr_data = false)
    return nil if list_of_meters.nil? || list_of_meters.empty?
    if list_of_meters.length == 1
      meter = list_of_meters.first
      meter = copy_meter_and_amr_data(meter) if copy_amr_data
      logger.info "Single meter of type #{fuel_type} - using as combined meter from #{meter.amr_data.start_date} to #{meter.amr_data.end_date} rather than creating new one"
      return meter
    end

    log_meter_dates(list_of_meters)

    combined_amr_data = aggregate_amr_data(list_of_meters, fuel_type)

    combined_name, combined_id, combined_floor_area, combined_pupils = combine_meter_meta_data(list_of_meters)

    if combined_meter.nil?
      mpan_mprn = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, fuel_type) unless @meter_collection.urn.nil?

      combined_meter = Dashboard::Meter.new(
        meter_collection: @meter_collection,
        amr_data: combined_amr_data,
        type: fuel_type,
        identifier: mpan_mprn,
        name: combined_name,
        floor_area: combined_floor_area,
        number_of_pupils: combined_pupils,
        meter_attributes: @meter_collection.pseudo_meter_attributes(:"aggregated_#{fuel_type}")
      )

      combined_meter.add_aggregate_partial_meter_coverage_component(list_of_meters.map{ |m| m.partial_meter_coverage})
    else
      logger.info "Combined meter #{combined_meter.mpan_mprn} already created"
      combined_meter.floor_area = combined_floor_area if combined_meter.floor_area.nil? || combined_meter.floor_area == 0
      combined_meter.number_of_pupils = combined_pupils if combined_meter.number_of_pupils.nil? || combined_meter.number_of_pupils == 0
      combined_meter.amr_data = combined_amr_data
    end

    calculate_carbon_emissions_for_meter(combined_meter, fuel_type)

    has_differential_meter = any_component_meter_differential?(list_of_meters, fuel_type, combined_meter.amr_data.start_date, combined_meter.amr_data.end_date)

    set_costs_for_combined_meter(combined_meter, list_of_meters, has_differential_meter)

    logger.info "Creating combined meter data #{combined_amr_data.start_date} to #{combined_amr_data.end_date}"
    logger.info "with floor area #{combined_floor_area} and #{combined_pupils} pupils"
    combined_meter
  end

  private def any_component_meter_differential?(list_of_meters, fuel_type, combined_meter_start_date, combined_meter_end_date)
    return false if fuel_type == :gas
    list_of_meters.each do |meter|
      return true if MeterTariffs.differential_tariff_in_date_range?(meter, combined_meter_start_date, combined_meter_end_date)
    end
    false
  end

  private def set_costs_for_combined_meter(combined_meter, list_of_meters, has_differential_meter)
    mpan_mprn = combined_meter.mpan_mprn
    start_date = combined_meter.amr_data.start_date # use combined meter start and end dates to conform with (deprecated) meter aggregation rules
    end_date = combined_meter.amr_data.end_date

    logger.info "Creating economic & accounting costs for combined meter #{mpan_mprn} fuel #{combined_meter.fuel_type} with #{list_of_meters.length} meters from #{start_date} to #{end_date}"

    set_economic_costs(combined_meter, list_of_meters, start_date, end_date, has_differential_meter)

    accounting_costs = AccountingCosts.combine_accounting_costs_from_multiple_meters(combined_meter, list_of_meters, start_date, end_date)
    combined_meter.amr_data.set_accounting_tariff_schedule(accounting_costs)
  end

  private def set_economic_costs(combined_meter, list_of_meters, start_date, end_date, has_differential_meter)
    mpan_mprn = combined_meter.mpan_mprn
    if has_differential_meter # so need pre aggregated economic costs as kwh to £ no longer additive
      logger.info 'Creating a multiple economic costs for differential tariff meter'
      economic_costs = EconomicCosts.combine_economic_costs_from_multiple_meters(combined_meter, list_of_meters, start_date, end_date)
    else
      logger.info 'Creating a parameterised economic cost meter'
      economic_costs = EconomicCostsParameterised.new(combined_meter)
    end
    combined_meter.amr_data.set_economic_tariff_schedule(economic_costs)
  end

  def log_meter_dates(list_of_meters)
    logger.info 'Combining the following meters'
    list_of_meters.each do |meter|
      logger.info sprintf('%-24.24s %-18.18s %s to %s', meter.display_name, meter.id, meter.amr_data.start_date.to_s, meter.amr_data.end_date)
      aggregation_rules = meter.attributes(:aggregation)
      unless aggregation_rules.nil?
        logger.info "                Meter has aggregation rules #{aggregation_rules}"
      end
    end
  end

  def group_sub_meters_by_fuel_type(list_of_meters)
    sub_meter_types = {}
    list_of_meters.each do |meter|
      meter.sub_meters.each do |sub_meter|
        fuel_type = meter.fuel_type
        sub_meter_types[fuel_type] = [] unless sub_meter_types.key?(fuel_type)
        sub_meter_types[fuel_type].push(sub_meter)
      end
    end
    sub_meter_types
  end

  def combine_sub_meters_deprecated(parent_meter, list_of_meters)
    sub_meter_types = group_sub_meters_by_fuel_type(list_of_meters)

    sub_meter_types.each do |fuel_type, sub_meters|
      combined_meter = aggregate_meters(parent_meter, sub_meters, fuel_type)
      parent_meter.sub_meters.push(combined_meter)
    end
  end
end
