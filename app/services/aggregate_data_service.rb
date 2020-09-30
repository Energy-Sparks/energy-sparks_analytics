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
      create_unaltered_aggregate_electricity_meter_for_pv_and_storage_heaters
      create_solar_pv_sub_meters if @meter_collection.sheffield_simulated_solar_pv_panels?
      aggregate_electricity_meters
      disaggregate_storage_heaters if @meter_collection.storage_heaters?
      create_solar_pv_sub_meters_using_meter_data if @meter_collection.low_carbon_hub_solar_pv_panels? || @meter_collection.solar_for_schools_solar_pv_panels?
      combine_solar_pv_submeters_into_aggregate if aggregate_solar_pv_sub_meters?
      set_post_aggregation_state_on_all_meters
    }
    calc_text = "Calculated meter aggregation in #{bm.round(3)} seconds"
    logger.info calc_text
    puts calc_text
  end

  private

  private def set_long_gap_boundary_on_all_meters
    @meter_collection.all_meters.each do |meter|
      meter.amr_data.set_long_gap_boundary
    end
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

  # if the electricity meter has a storage heater, split the meter
  # into 2 one with storage heater only kwh, the other with the remainder
  private def disaggregate_storage_heaters
    disaggregated_meter_list, non_storage_heater_meters = split_normal_meters_and_storage_heater_meters

    if non_storage_heater_meters.length == 0 && disaggregated_meter_list.length == 1
      # in simple case, just one meter at school, so meter and aggregate is one and the same
      # used for backwards compatibility as preserves original meter mpan and associated meter attributes mpan association
      @meter_collection.aggregated_electricity_meters = disaggregated_meter_list[0][:electricity_minus_storage_heater_meter]
      @meter_collection.storage_heater_meter = disaggregated_meter_list[0][:storage_heater_meter]
    else
      # we have multiple meters at the school with storage heaters
      # so we need to create the aggregate storage heater meter from the sum of the components
      # and a aggregated electricity meter from the sum of its components (disaggregated storage heater data + normal sub meters)

      calculate_aggregate_storage_heater_meter(disaggregated_meter_list)

      calculate_aggregated_disaggregated_electricity_meter_for_storage_heater_school(disaggregated_meter_list, non_storage_heater_meters)
    end
  end

  private def split_normal_meters_and_storage_heater_meters
    disaggregated_meter_list = []
    non_storage_heater_meters = []
    @electricity_meters.each do |electricity_meter|
      unless electricity_meter.storage_heater_setup.nil?
        disaggregated_meter = disaggregate_one_storage_heater_meter(electricity_meter)
        disaggregated_meter_list.push(disaggregated_meter)
      else
        non_storage_heater_meters.push(electricity_meter)
      end
    end
    [disaggregated_meter_list, non_storage_heater_meters]
  end

  private def disaggregate_one_storage_heater_meter(electricity_meter)
    logger.info 'Disaggregating electricity meter into 1x storage heater only and 1 x remainder'

    # create a new sub meter with the original amr data as a sub meter
    # replace the existing electricity meters amr_date with just the non storag heater amr_data
    electric_only_amr, storage_heater_amr = electricity_meter.storage_heater_setup.disaggregate_amr_data(electricity_meter.amr_data, electricity_meter.mpan_mprn)

    original_electricity_meter_copy = create_modified_meter_copy(
      electricity_meter,
      electricity_meter.amr_data,
      :electricity,
      electricity_meter.id,
      electricity_meter.name,
      :storage_heater_disaggregated_electricity
    )
    electricity_meter.sub_meters.push(original_electricity_meter_copy)

    electricity_meter.amr_data = electric_only_amr
    calculate_meter_carbon_emissions_and_costs(electricity_meter, :electricity)

    storage_heater_meter = create_modified_meter_copy(
      electricity_meter,
      storage_heater_amr,
      :storage_heater,
      electricity_meter.id,
      "#{electricity_meter.name} storage heater only",
      :storage_heater_disaggregated_storage_heater
    )

    calculate_meter_carbon_emissions_and_costs(storage_heater_meter, :electricity)

    # set the synthetic meter identifier once the tariffs have been assigned above using the real meter identifier
    electricity_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :electricity_minus_storage_heater))
    storage_heater_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :storage_heater_only))

    proportion_out_accounting_standing_charges(storage_heater_meter, electricity_meter)

    electricity_meter.sub_meters.push(storage_heater_meter)

    {
      electricity_minus_storage_heater_meter: electricity_meter,
      storage_heater_meter: storage_heater_meter
    }
  end

  private def calculate_aggregate_storage_heater_meter(disaggregated_meter_list)
    storage_meters_list = disaggregated_meter_list.map { |h| h[:storage_heater_meter] }

    aggregate_storage_heater_amr_data = aggregate_amr_data(
      storage_meters_list,
      :electricity
      )

    aggregate_storage_heater_mpan = Dashboard::Meter.synthetic_mpan_mprn(meter_collection.aggregated_electricity_meters.id, :storage_heater_only)

    aggregate_storage_heater_meter = create_modified_meter_copy(
      meter_collection.aggregated_electricity_meters, # pass in floor area, pupil numbers
      aggregate_storage_heater_amr_data,
      :storage_heater,
      aggregate_storage_heater_mpan,
      "#{meter_collection.aggregated_electricity_meters.name} storage heater only",
      :storage_heater_aggregated
    )

    calculate_meter_carbon_emissions_and_costs(aggregate_storage_heater_meter, :electricity)

    @meter_collection.storage_heater_meter = aggregate_storage_heater_meter
  end

  private def calculate_aggregated_disaggregated_electricity_meter_for_storage_heater_school(disaggregated_meter_list, non_storage_heater_meters)
    disaggregated_electricity_meters_list = disaggregated_meter_list.map { |h| h[:electricity_minus_storage_heater_meter] }

    # including the non-storage heater meter data!
    disaggregated_electricity_meters_list += non_storage_heater_meters unless non_storage_heater_meters.empty?

    disaggregated_electricity_amr_data = aggregate_amr_data(
      disaggregated_electricity_meters_list,
      :electricity
    )
    @meter_collection.aggregated_electricity_meters.amr_data = disaggregated_electricity_amr_data

    calculate_meter_carbon_emissions_and_costs(@meter_collection.aggregated_electricity_meters, :electricity)
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
    logger.info 'Creating solar PV data from Sheffield PV feed'
    @electricity_meters.each do |electricity_meter|
      next unless electricity_meter.sheffield_simulated_solar_pv_panels?

      logger.info 'Creating an artificial solar pv meter and associated amr data'

      disaggregated_data = electricity_meter.solar_pv_setup.create_solar_pv_data(
        electricity_meter.amr_data,
        @meter_collection,
        electricity_meter.mpan_mprn
      )

      solar_pv_meter = create_modified_meter_copy(
        electricity_meter,
        disaggregated_data[:solar_consumed_onsite],
        :solar_pv,
        Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :solar_pv),
        SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
        :solar_pv_consumed_sub_meter
      )
      logger.warn "Created meter onsite consumed electricity pv data from #{disaggregated_data[:solar_consumed_onsite].start_date} to #{disaggregated_data[:solar_consumed_onsite].end_date} #{disaggregated_data[:solar_consumed_onsite].total.round(0)}kWh"

      electricity_meter.sub_meters.push(solar_pv_meter)

      exported_pv = create_modified_meter_copy(
        electricity_meter,
        disaggregated_data[:exported],
        :solar_pv,
        Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :exported_solar_pv),
        SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
        :solar_pv_exported_sub_meter
      )
      logger.info "Created meter onsite consumed electricity pv data from #{disaggregated_data[:exported].start_date} to #{disaggregated_data[:exported].end_date} #{disaggregated_data[:exported].total.round(0)}kWh"

      electricity_meter.sub_meters.push(exported_pv)

      # make the original top level meter a sub meter of itself

      original_electric_meter = create_modified_meter_copy(
        electricity_meter,
        electricity_meter.amr_data,
        :electricity,
        electricity_meter.id,
        SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
        :solar_pv_original_sub_meter
      )

      logger.info "Making original mains consumption meter a submeter from #{electricity_meter.amr_data.start_date} to #{electricity_meter.amr_data.end_date} #{electricity_meter.amr_data.total.round(0)}kWh"

      electricity_meter.sub_meters.push(original_electric_meter)

      # replace the AMR data of the top level meter with the
      # combined original mains consumption data plus the solar pv data
      # currently the updated meter inherits the carbon emissions and costs of the original
      # which implies the solar pv is zero carbon and zero cost
      # a full accounting treatment will need to deal with FITs and exports..... TODO(PH, 7Apr2019)

      electricity_meter.amr_data = disaggregated_data[:electricity_consumed_onsite]
      electricity_meter.id = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
      electricity_meter.name = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV

      calculate_meter_carbon_emissions_and_costs(original_electric_meter, :electricity)
      calculate_meter_carbon_emissions_and_costs(electricity_meter, :electricity)
      calculate_meter_carbon_emissions_and_costs(solar_pv_meter, :electricity)
      calculate_meter_carbon_emissions_and_costs(exported_pv, :exported_solar_pv)

      @meter_collection.solar_pv_meter = solar_pv_meter
    end
  end

  # Low Carbon Hub based solar PV aggregation
  #
  # similar to Sheffield PV based create_solar_pv_sub_meters() function
  # except the data comes in a more precalculated form, so its more a
  # matter of moving meters around, plus some imple maths
  #
  # Low carbon hub provides 4 sets of meter readings: 'solar PV production', 'exported electricity', 'mains consumption', 'solar pv concumed onsite'
  #
  # 1. Energy Sparks currently needs an aggregate meter containing all school consumption from whereever its sourced
  #    which in this case is 'mains consumption' + 'solar PV production' - 'exported electricity'
  # 2. Solar PV consumed onsite = 'solar PV production' - 'exported electricity'
  # 3. Exported PV = 'exported electricity'
  #
  # the data should arrive in the aggregate meter service as a single electricity meter, with 2 sub meters
  # prior to this the single electricity meter will have been promoted to be the aggregate electricity meter as well
  private def create_solar_pv_sub_meters_using_meter_data
    check_solar_pv_meter_configuration

    meters = find_solar_pv_meters
    mains_meter   = meters[:electricity]
    solar_meter   = meters[:solar_pv]
    export_meter  = meters[:exported_solar_pv]

    # this is required for charting and p&l
    export_meter.name = SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME

    # invert export data so negative to match internal convention if for example
    # supplied as positive numbers from Solar for Schools

    export_meter.amr_data =invert_export_amr_data_if_positive(export_meter.amr_data)

    # move solar pv meter data from sub meter to top level
    # TODO(PH, 15Aug2019) - review what prices should used for this
    #                     - Low Carbon Hub schools probably don't benefit from this
    calculate_meter_carbon_emissions_and_costs(solar_meter, :solar_pv)
    @meter_collection.solar_pv_meter = solar_meter
    mains_meter.sub_meters.delete_if { |sub_meter| sub_meter.fuel_type == :solar_pv }

    # make the original meter a sub meter of the combined electricity meter

    original_electric_meter = create_modified_meter_copy(
      mains_meter,
      mains_meter.amr_data,
      :electricity,
      mains_meter.id,
      SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
      :solar_pv_original_sub_meter,
    )
    mains_meter.sub_meters.push(original_electric_meter)
    assign_unaltered_low_carbon_hub_mains_consumption_meter(original_electric_meter)
    logger.info "Making original mains consumption meter a submeter from #{mains_meter.amr_data.start_date} to #{mains_meter.amr_data.end_date} #{mains_meter.amr_data.total.round(0)}kWh"

    # calculated onsite consumed electricity = solar pv production - export

    onsite_consumpton_amr_data = aggregate_amr_data(
      [solar_meter, export_meter],
      :electricity
      )

    solar_pv_consumed_onsite_meter = create_modified_meter_copy(
      mains_meter,
      onsite_consumpton_amr_data,
      :solar_pv,
      Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :solar_pv),
      SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
      :solar_pv_consumed_sub_meter
    )
    mains_meter.sub_meters.push(solar_pv_consumed_onsite_meter)

    # calculate a new aggregate meter which is the 'mains consumpion' + 'solar pv production' - 'exported'
    # export kwh values already -tve
    electric_plus_pv_minus_export = aggregate_amr_data(
      [mains_meter, solar_meter, export_meter],
      :electricity
      )

    mains_meter.amr_data = electric_plus_pv_minus_export
    mains_meter.name = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
    calculate_meter_carbon_emissions_and_costs(mains_meter, :electricity)

    puts "Totals: pv #{solar_meter.amr_data.total} exp #{export_meter.amr_data.total} mains #{mains_meter.amr_data.total} pvons #{solar_pv_consumed_onsite_meter.amr_data.total}"
  end

  def assign_unaltered_low_carbon_hub_mains_consumption_meter(meter)
    calculate_meter_carbon_emissions_and_costs(meter, :electricity)
    meter.amr_data.set_post_aggregation_state
    assign_unaltered_electricity_meter(meter)
  end

  # defensive programming to ensure correct data arrives from front end, and analytics
  private def check_solar_pv_meter_configuration
    raise EnergySparksUnexpectedStateException.new, 'Expecting an aggregate electricity meter for solar pv meter aggregation' if @meter_collection.aggregated_electricity_meters.nil?
    raise EnergySparksUnexpectedStateException.new, 'Only 1 electricity meter currently supported for solar pv meter aggregation' if @meter_collection.electricity_meters.length != 1
    raise EnergySparksUnexpectedStateException.new, '2 electricity sub meters required for solar pv meter aggregation' if @meter_collection.electricity_meters[0].sub_meters.length != 2
    meters = find_solar_pv_meters
    raise EnergySparksUnexpectedStateException.new, 'Missing solar pv sub meter from aggregation' if meters[:solar_pv].nil?
    raise EnergySparksUnexpectedStateException.new, 'Missing export sub meter from aggregation' if meters[:exported_solar_pv].nil?
    raise EnergySparksUnexpectedStateException.new, 'Missing solar pv amr data from aggregation' if meters[:solar_pv].amr_data.length == 0
    raise EnergySparksUnexpectedStateException.new, 'Missing export amr data from aggregation' if meters[:exported_solar_pv].amr_data.length == 0
  end

  private def invert_export_amr_data_if_positive(amr_data)
    # using 0.10000000001 as LCC seems to have lots of 0.1 values?????
    histo = amr_data.histogram_half_hours_data([-0.10000000001,+0.10000000001])
    negative = histo[0] > (histo[2] * 10) # 90%
    message = negative ? "is negative therefore leaving unchanged" : "is positive therefore inverting to conform to internal convention"
    logger.info "Export amr pv data #{message}"
    amr_data.scale_kwh(-1) unless negative
    amr_data
  end

  private def find_solar_pv_meters
    mains_consumption_meter = @meter_collection.electricity_meters[0]
    {
      electricity:        mains_consumption_meter,
      solar_pv:           mains_consumption_meter.sub_meters.find { |meter| meter.fuel_type == :solar_pv },
      exported_solar_pv:  mains_consumption_meter.sub_meters.find { |meter| meter.fuel_type == :exported_solar_pv }
    }
  end

  private def lookup_synthetic_meter(type)
    meter_id = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, type)
    @meter_collection.meter?(meter_id, true)
  end

  private def create_modified_meter_copy(meter, amr_data, type, identifier, name, pseudo_meter_name)
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
      meter_attributes: meter.meter_attributes.merge(@meter_collection.pseudo_meter_attributes(pseudo_meter_name))
    )
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
    if @meter_collection.sheffield_simulated_solar_pv_panels? ||
       @meter_collection.storage_heaters?
       # but not low carbon hub meters, as split already taken place
      calculate_meters_carbon_emissions_and_costs(@electricity_meters, :electricity)
      unaltered_aggregate_meter = aggregate_main_meters(nil, @electricity_meters, :electricity, true)
      assign_unaltered_electricity_meter(unaltered_aggregate_meter)
    end
  end

  def assign_unaltered_electricity_meter(meter)
    @meter_collection.unaltered_aggregated_electricity_meters ||= meter
  end

  private def aggregate_amr_data(meters, type)
    if meters.length == 1
      logger.info "Single meter, so aggregation is a reference to itself not an aggregate meter"
      return meters.first.amr_data # optimisaton if only 1 meter, then its its own aggregate
    end
    min_date, max_date = combined_amr_data_date_range(meters)
    logger.info "Aggregating data between #{min_date} #{max_date}"

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

  def aggregate_main_meters(combined_meter, list_of_meters, type, copy_amr_data = false)
    logger.info "Aggregating #{list_of_meters.length} meters"
    combined_meter = aggregate_meters(combined_meter, list_of_meters, type, copy_amr_data)
    # combine_sub_meters_deprecated(combined_meter, list_of_meters) # TODO(PH, 15Aug2019) - not sure about the history behind this call, perhaps simulator, but commented out for the moment
    combined_meter
  end

  def aggregate_solar_pv_sub_meters?
    @meter_collection.solar_pv_panels? && @meter_collection.electricity_meters.length > 1
  end

  def combine_solar_pv_submeters_into_aggregate
    aggregate_meter = @meter_collection.aggregated_electricity_meters
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
  end

  private def calculate_carbon_emissions_for_meter(meter, fuel_type)
    if fuel_type == :electricity || fuel_type == :aggregated_electricity # TODO(PH, 6Apr19) remove : aggregated_electricity once analytics meter meta data loading changed
      meter.amr_data.set_carbon_emissions(meter.id, nil, @meter_collection.grid_carbon_intensity)
    else
      meter.amr_data.set_carbon_emissions(meter.id, EnergyEquivalences::UK_GAS_CO2_KG_KWH, nil)
    end
  end

  private def calculate_costs_for_meter(meter)
    logger.info "Creating economic & accounting costs for #{meter.mpan_mprn} fuel #{meter.fuel_type} from #{meter.amr_data.start_date} to #{meter.amr_data.end_date}"
    meter.amr_data.set_economic_tariff(meter)
    meter.amr_data.set_accounting_tariff(meter)
  end

  private def calculate_meter_carbon_emissions_and_costs(meter, fuel_type)
    calculate_carbon_emissions_for_meter(meter, fuel_type)
    calculate_costs_for_meter(meter)
  end

  private def calculate_meters_carbon_emissions_and_costs(meters, fuel_type)
    meters.each do |meter|
      calculate_meter_carbon_emissions_and_costs(meter, fuel_type)
    end
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
