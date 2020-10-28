# solar pv methods associated with AggregateDataService (see aggregation_service.rb)
class AggregateDataService
  include Logging

  private

  def process_solar_pv_electricity_meters
    reorganise_solar_pv_sub_meters if @meter_collection.real_solar_pv_metering_x3? || @meter_collection.solar_pv_sub_meters_to_be_aggregated > 0
    @electricity_meters.each do |electricity_meter|
      if production_no_export_meter?(electricity_meter)
        # convoluted: reorganise_solar_pv_sub_meters sets up subclassed SolarPVPanels
        # so Sheffield process correctly calculates export
        create_solar_pv_sub_meters_using_sheffield_pv_estimates(electricity_meter)
      elsif electricity_meter.sheffield_simulated_solar_pv_panels?
        create_solar_pv_sub_meters_using_sheffield_pv_estimates(electricity_meter)
      elsif production_no_export_meter?(electricity_meter)
        create_synthetic_production_submeter(electricity_meter)
        create_solar_pv_sub_meters_using_meter_data(electricity_meter)
      elsif electricity_meter.real_solar_pv_metering_x3? || electricity_meter.solar_pv_sub_meters_to_be_aggregated == 2
        create_solar_pv_sub_meters_using_meter_data(electricity_meter)
      end
    end
  end

  # creates artificial PV meters, if solar pv present by scaling
  # 1/2 hour yield data from Sheffield University by the kWp(s) of
  # the PV installation; note the kWh is negative as its a producer
  # rather than a consumer
  def create_solar_pv_sub_meters_using_sheffield_pv_estimates(electricity_meter)
    logger.info 'Creating solar PV data from Sheffield PV feed'

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
    logger.info "Created meter exported data from #{disaggregated_data[:exported].start_date} to #{disaggregated_data[:exported].end_date} #{disaggregated_data[:exported].total.round(0)}kWh"

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

  def create_synthetic_production_submeter(electricity_meter)
    mpan_solar_pv = Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.mpan_mprn, :solar_pv)
    pv_amr = create_solar_pv_production_amr_from_sheffield_university(electricity_amr, @meter_collection, mpan_solar_pv)
    solar_pv_meter = create_modified_meter_copy(
      electricity_meter,
      pv_amr,
      :solar_pv,
      mpan_solar_pv,
      SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      :solar_pv_sub_meter
    )
    electricity_meter.sub_meters.push(solar_pv_meter)
  end

  # Meter aggregation where we have multiple meters metering the solar PV
  # 
  # similar to Sheffield PV based create_solar_pv_sub_meters() function
  # except the data comes in a more precalculated form, so its more a
  # matter of moving meters around, plus some simple maths
  #
  # Up to 4 sets of meter readings are used: 'solar PV production', 'exported electricity', 'mains consumption', 'solar pv concumed onsite'
  #
  # 1. Energy Sparks currently needs an aggregate meter containing all school consumption from whereever its sourced
  #    which in this case is 'mains consumption' + 'solar PV production' - 'exported electricity'
  # 2. Solar PV consumed onsite = 'solar PV production' - 'exported electricity'
  # 3. Exported PV = 'exported electricity'
  #
  def create_solar_pv_sub_meters_using_meter_data(electricity_meter)
    check_solar_pv_meter_configuration(electricity_meter)

    meters = find_solar_pv_meters(electricity_meter)
    mains_meter   = meters[:electricity]
    solar_meter   = meters[:solar_pv]
    export_meter  = meters[:exported_solar_pv]

    # this is required for charting and p&l
    export_meter.name = SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME

    # invert export data so negative to match internal convention if for example
    # supplied as positive numbers from Solar for Schools

    export_meter.amr_data = invert_export_amr_data_if_positive(export_meter.amr_data)

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
  def check_solar_pv_meter_configuration(electricity_meter)
    # raise EnergySparksUnexpectedStateException.new, 'Expecting an aggregate electricity meter for solar pv meter aggregation' if @meter_collection.aggregated_electricity_meters.nil?
    # raise EnergySparksUnexpectedStateException.new, 'Only 1 electricity meter currently supported for solar pv meter aggregation' if @meter_collection.electricity_meters.length != 1
    raise EnergySparksUnexpectedStateException.new, '2 electricity sub meters required for solar pv meter aggregation' if electricity_meter.sub_meters.length != 2
    meters = find_solar_pv_meters(electricity_meter)
    raise EnergySparksUnexpectedStateException.new, 'Missing solar pv sub meter from aggregation' if meters[:solar_pv].nil?
    raise EnergySparksUnexpectedStateException.new, 'Missing export sub meter from aggregation' if meters[:exported_solar_pv].nil?
    raise EnergySparksUnexpectedStateException.new, 'Missing solar pv amr data from aggregation' if meters[:solar_pv].amr_data.length == 0
    raise EnergySparksUnexpectedStateException.new, 'Missing export amr data from aggregation' if meters[:exported_solar_pv].amr_data.length == 0
  end

  def invert_export_amr_data_if_positive(amr_data)
    # using 0.10000000001 as LCC seems to have lots of 0.1 values?????
    histo = amr_data.histogram_half_hours_data([-0.10000000001,+0.10000000001])
    negative = histo[0] > (histo[2] * 10) # 90%
    message = negative ? "is negative therefore leaving unchanged" : "is positive therefore inverting to conform to internal convention"
    logger.info "Export amr pv data #{message}"
    amr_data.scale_kwh(-1) unless negative
    amr_data
  end

  def find_solar_pv_meters(mains_consumption_meter)
    {
      electricity:        mains_consumption_meter,
      solar_pv:           mains_consumption_meter.sub_meters.find { |meter| meter.fuel_type == :solar_pv },
      exported_solar_pv:  mains_consumption_meter.sub_meters.find { |meter| meter.fuel_type == :exported_solar_pv }
    }
  end

  def export_meter?(mains_consumption_meter)
    mains_consumption_meter.sub_meters.any? { |meter| meter.fuel_type == :exported_solar_pv }
  end

  def production_meter?(mains_consumption_meter)
    mains_consumption_meter.sub_meters.any? { |meter| meter.fuel_type == :solar_pv }
  end

  def production_no_export_meter?(mains_consumption_meter)
    production_meter?(mains_consumption_meter) && !export_meter?(mains_consumption_meter)
  end

  def export_no_production_meter?(mains_consumption_meter)
    !production_meter?(mains_consumption_meter) && export_meter?(mains_consumption_meter)
  end

  def reorganise_solar_pv_sub_meters
    logger.info 'Reorganising solar PV meters imported as main meters into submeters of the relevent mains import meter'
    solar_pv_meters_with_mpan_remapping_attributes.each do |mains_meter, maps|
      maps.each do |_type, mpan|
        meter = @meter_collection.electricity_meters.find{ |meter1| meter1.mpan_mprn == mpan }
        @meter_collection.electricity_meters.delete_if{ |meter1| meter1.mpan_mprn == mpan }
        pv_panel_setup(mains_meter, meter) if meter.fuel_type == :solar_pv
        mains_meter.sub_meters.push(meter)
      end
    end
    # TODO(PH, 27Oct2020) remove once meter attribute mappings are setup on production
    legacy_reorganise_solar_pv_sub_meters
  end

  def pv_panel_setup(mains_meter, pv_meter)
    mains_meter.solar_pv_setup = SolarPVPanelsWithProductionMeter.new(pv_meter.attributes(:solar_pv), pv_meter)
  end

  # TODO(PH, 27Oct2020) remove once meter attribute mappings are setup on production
  def legacy_reorganise_solar_pv_sub_meters
    logger.info 'Reorganising Solar for Schools meters to look like Low Carbon Hub'
    pv_meter     = @meter_collection.electricity_meters.find{ |meter| meter.fuel_type == :solar_pv }
    export_meter = @meter_collection.electricity_meters.find{ |meter| meter.fuel_type == :exported_solar_pv }
    mains_meter  = @meter_collection.electricity_meters.find{ |meter| meter.fuel_type == :electricity }
    if mains_meter
      if pv_meter
        @meter_collection.electricity_meters.delete(pv_meter)
        mains_meter.sub_meters.push(pv_meter)
      end
      if export_meter
        @meter_collection.electricity_meters.delete(export_meter)
        mains_meter.sub_meters.push(export_meter)
      end
    end
  end

  def solar_pv_meters_with_mpan_remapping_attributes
    mains_meters  = @meter_collection.electricity_meters.select{ |meter| meter.fuel_type == :electricity }
    mains_meters.map do |mains_meter|
      [
        mains_meter,
        mains_meter.attributes(:solar_pv_mpan_meter_mapping)
      ]
    end.select{ |meter| !meter[1].nil? }
  end

  def more_than_one_solar_pv_sub_meter?
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

end