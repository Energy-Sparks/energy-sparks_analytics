# This should take a meter collection and populate
# it with aggregated & validated data
require 'benchmark/memory'
class AggregateDataService
  include Logging

  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @heat_meters        = @meter_collection.heat_meters
    @electricity_meters = @meter_collection.electricity_meters
  end

  # This is called by the EnergySparks codebase
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

  def aggregate_heat_and_electricity_meters
    bm = Benchmark.realtime {
      aggregate_heat_meters
      aggregate_electricity_meters
      disaggregate_storage_heaters if @meter_collection.storage_heaters?
      create_solar_pv_sub_meters if @meter_collection.solar_pv_panels?
      set_post_aggregation_state_on_all_meters
    }
    calc_text = "Calculated meter aggregation in #{bm.round(3)} seconds"
    logger.info calc_text
    puts calc_text
  end

  private

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

  # if the electricity meter has a storage heater, split the meter
  # into 2 one with storage heater only kwh, the other with the remainder
  private def disaggregate_storage_heaters
    @electricity_meters.each do |electricity_meter|
      next if electricity_meter.storage_heater_setup.nil?

      logger.info 'Disaggregating electricity meter into 1x storage heater only and 1 x remainder'

      # create a new sub meter with the original amr data as a sub meter
      # replace the existing electricity meters amr_date with just the non storag heater amr_data
      electric_only_amr, storage_heater_amr = electricity_meter.storage_heater_setup.disaggregate_amr_data(electricity_meter.amr_data, electricity_meter.mpan_mprn)

      original_electricity_meter_copy = create_modified_meter_copy(
        electricity_meter,
        electricity_meter.amr_data,
        :electricity,
        electricity_meter.id,
        electricity_meter.name
      )
      electricity_meter.sub_meters.push(original_electricity_meter_copy)

      electricity_meter.amr_data = electric_only_amr
      calculate_meter_carbon_emissions_and_costs(electricity_meter, :electricity)

      storage_heater_meter = create_modified_meter_copy(
        electricity_meter,
        storage_heater_amr,
        :storage_heater,
        electricity_meter.id,
        "#{electricity_meter.name} storage heater only"
      )

      calculate_meter_carbon_emissions_and_costs(storage_heater_meter, :electricity)

      # set the synthetic meter identifier once the tariffs have been assigned above using the real meter identifier
      electricity_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :electricity_minus_storage_heater))
      storage_heater_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :storage_heater_only))

      proportion_out_accounting_standing_charges(storage_heater_meter, electricity_meter)

      electricity_meter.sub_meters.push(storage_heater_meter)
      @meter_collection.storage_heater_meter = storage_heater_meter
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

  # creates artificial PV meters, if solar pv present by scaling
  # 1/2 hour yield data from Sheffield University by the kWp(s) of
  # the PV installation; note the kWh is negative as its a producer
  # rather than a consumer
  private def create_solar_pv_sub_meters
    @electricity_meters.each do |electricity_meter|
      next if electricity_meter.solar_pv_setup.nil?

      logger.info 'Creating an artificial solar pv meter and associated amr data'

      solar_amr = electricity_meter.solar_pv_setup.create_solar_pv_amr_data(
        electricity_meter.amr_data,
        @meter_collection,
        electricity_meter.mpan_mprn
      )

      solar_pv_meter = create_modified_meter_copy(
        electricity_meter,
        solar_amr,
        :solar_pv,
        electricity_meter.id.to_i + 10000000, # TODO(PH,21Mar2019) - need proper synthetic id
        'Electricity consumed from solar PV panels'
      )
      logger.info "Created meter onsite consumed electricity pv data from #{solar_amr.start_date} to #{solar_amr.end_date} #{solar_amr.total.round(0)}kWh"

      electricity_meter.sub_meters.push(solar_pv_meter)

      # make the original top level meter a sub meter of itself

      original_electric_meter = create_modified_meter_copy(
        electricity_meter,
        electricity_meter.amr_data,
        :electricity,
        electricity_meter.id,
        'Electricity consumed from mains'
      )

      logger.info "Making original mains consumption meter a submeter from #{electricity_meter.amr_data.start_date} to #{electricity_meter.amr_data.end_date} #{electricity_meter.amr_data.total.round(0)}kWh"

      electricity_meter.sub_meters.push(original_electric_meter)

      # replace the AMR data of the top level meter with the
      # combined original mains consumption data plus the solar pv data

      electric_plus_pv_amr_data = aggregate_amr_data(
        [electricity_meter, solar_pv_meter],
        :electricity
        )

      # currently the updated meter inherits the carbon emissions and costs of the original
      # which implies the solar pv is zero carbon and zero cost
      # a full accounting treatment will need to deal with FITs and exports..... TODO(PH, 7Apr2019)

      logger.info "Assigning solar + mains amr to main meter from #{electric_plus_pv_amr_data.start_date} to #{electric_plus_pv_amr_data.end_date} #{electric_plus_pv_amr_data.total.round(0)}kWh"

      electricity_meter.amr_data = electric_plus_pv_amr_data
      electricity_meter.id = "#{electricity_meter.id} plus pv"
      electricity_meter.name = "#{electricity_meter.name} plus pv"

      calculate_meter_carbon_emissions_and_costs(original_electric_meter, :electricity)
      calculate_meter_carbon_emissions_and_costs(electricity_meter, :electricity)
      calculate_meter_carbon_emissions_and_costs(solar_pv_meter, :electricity)

      @meter_collection.solar_pv_meter = solar_pv_meter
    end
  end

  private def create_modified_meter_copy(meter, amr_data, type, identifier, name)
    Dashboard::Meter.new(
      meter_collection: meter_collection,
      amr_data: amr_data,
      type: type,
      identifier: identifier,
      name: name,
      floor_area: meter.floor_area,
      number_of_pupils: meter.number_of_pupils,
      solar_pv_installation: meter.solar_pv_setup,
      storage_heater_config: meter.storage_heater_setup,
      meter_attributes: meter.meter_attributes
    )
  end

  def aggregate_heat_meters
    calculate_meters_carbon_emissions_and_costs(@heat_meters, :gas)
    @meter_collection.aggregated_heat_meters = aggregate_main_meters(@meter_collection.aggregated_heat_meters, @heat_meters, :gas)
  end

  def aggregate_electricity_meters
    calculate_meters_carbon_emissions_and_costs(@electricity_meters, :electricity)
    @meter_collection.aggregated_electricity_meters = aggregate_main_meters(@meter_collection.aggregated_electricity_meters, @electricity_meters, :electricity)
  end

  private def aggregate_amr_data(meters, type)
    if meters.length == 1
      logger.info "Single meter, so aggregation is a reference to itself not an aggregate meter"
      return meters.first.amr_data # optimisaton if only 1 meter, then its its own aggregate
    end
    min_date, max_date = combined_amr_data_date_range(meters)
    logger.info "Aggregating data between #{min_date} #{max_date}"

    mpan_mprn = 'NEEDSFIXING'
    mpan_mprn = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, meters[0].fuel_type) unless @meter_collection.urn.nil?
    combined_amr_data = AMRData.new(type)
    (min_date..max_date).each do |date|
      valid_meters_for_date = meters.select { |meter| meter.amr_data.date_exists?(date) }
      amr_data_for_date_x48_valid_meters = valid_meters_for_date.map { |meter| meter.amr_data.days_kwh_x48(date) }
      combined_amr_data_x48 = AMRData.fast_add_multiple_x48_x_x48(amr_data_for_date_x48_valid_meters)
      days_data = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, combined_amr_data_x48)
      combined_amr_data.add(date, days_data)
    end
    combined_amr_data
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

  def aggregate_main_meters(combined_meter, list_of_meters, type)
    logger.info "Aggregating #{list_of_meters.length} meters"
    combined_meter = aggregate_meters(combined_meter, list_of_meters, type)
    combine_sub_meters(combined_meter, list_of_meters)
    combined_meter
  end

  private def calculate_carbon_emissions_for_meter(meter, fuel_type)
    if fuel_type == :electricity || fuel_type == :aggregated_electricity # TODO(PH, 6Apr19) remove : aggregated_electricity once analytics meter meta data loading changed
      meter.amr_data.set_carbon_emissions(meter.id, nil, @meter_collection.grid_carbon_intensity)
    else
      meter.amr_data.set_carbon_emissions(meter.id, EnergyEquivalences::UK_GAS_CO2_KG_KWH, nil)
    end
  end

  private def calculate_costs_for_meter(meter, fuel_type)
    logger.info "Creating economic & accounting costs for #{meter.mpan_mprn} fuel #{meter.fuel_type} from #{meter.amr_data.start_date} to #{meter.amr_data.end_date}"
 
    meter.amr_data.set_economic_tariff(meter.mpan_mprn, meter.fuel_type, @meter_collection.default_energy_purchaser)
    meter.amr_data.set_accounting_tariff(meter.mpan_mprn, meter.fuel_type, @meter_collection.default_energy_purchaser)
  end

  private def calculate_meter_carbon_emissions_and_costs(meter, fuel_type)
    calculate_carbon_emissions_for_meter(meter, fuel_type)
    calculate_costs_for_meter(meter, fuel_type)
  end

  private def calculate_meters_carbon_emissions_and_costs(meters, fuel_type)
    meters.each do |meter|
      calculate_meter_carbon_emissions_and_costs(meter, fuel_type)
    end
  end

  private def aggregate_meters(combined_meter, list_of_meters, fuel_type)
    return nil if list_of_meters.nil? || list_of_meters.empty?
    if list_of_meters.length == 1
      meter = list_of_meters.first
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
        number_of_pupils: combined_pupils
      )
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
      return true if MeterTariffs.differential_tariff_in_date_range?(meter.mpan_mprn, combined_meter_start_date, combined_meter_end_date)
    end
    false
  end

  private def set_costs_for_combined_meter(combined_meter, list_of_meters, has_differential_meter)
    mpan_mprn = combined_meter.mpan_mprn
    start_date = combined_meter.amr_data.start_date # use combined meter start and end dates to conform with (deprecated) meter aggregation rules
    end_date = combined_meter.amr_data.end_date

    logger.info "Creating economic & accounting costs for combined meter #{mpan_mprn} fuel #{combined_meter.fuel_type} with #{list_of_meters.length} meters from #{start_date} to #{end_date}"

    set_economic_costs(combined_meter, list_of_meters, start_date, end_date, has_differential_meter)

    accounting_costs = AccountingCosts.combine_accounting_costs_from_multiple_meters(mpan_mprn, list_of_meters, start_date, end_date)
    combined_meter.amr_data.set_accounting_tariff_schedule(accounting_costs)
  end

  private def set_economic_costs(combined_meter, list_of_meters, start_date, end_date, has_differential_meter)
    mpan_mprn = combined_meter.mpan_mprn
    if has_differential_meter # so need pre aggregated economic costs as kwh to £ no longer additive
      logger.info 'Creating a multiple economic costs for differential tariff meter'
      economic_costs = EconomicCosts.combine_economic_costs_from_multiple_meters(mpan_mprn, list_of_meters, start_date, end_date)
    else
      logger.info 'Creating a parameterised economic cost meter'
      economic_costs = EconomicCostsParameterised.new(mpan_mprn, combined_meter.amr_data, combined_meter.fuel_type, @meter_collection.default_energy_purchaser)
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

  def combine_sub_meters(parent_meter, list_of_meters)
    sub_meter_types = group_sub_meters_by_fuel_type(list_of_meters)

    sub_meter_types.each do |fuel_type, sub_meters|
      combined_meter = aggregate_meters(sub_meters, fuel_type)
      parent_meter.sub_meters.push(combined_meter)
    end
  end

  # for overlapping data i.e. date range where there is data for all meters
  def combined_amr_data_date_range(meters)
    start_dates = []
    end_dates = []
    meters.each do |meter|
      aggregation_rules = meter.attributes(:aggregation)
      if aggregation_rules.nil?
        start_dates.push(meter.amr_data.start_date)
      elsif !(aggregation_rules.include?(:ignore_start_date) ||
              aggregation_rules.include?(:deprecated_include_but_ignore_start_date))
        start_dates.push(meter.amr_data.start_date)
      end
      if aggregation_rules.nil?
        end_dates.push(meter.amr_data.end_date)
      elsif !(aggregation_rules.include?(:ignore_end_date) ||
        aggregation_rules.include?(:deprecated_include_but_ignore_end_date))
        end_dates.push(meter.amr_data.end_date)
      end
    end
    [start_dates.sort.last, end_dates.sort.first]
  end
end
