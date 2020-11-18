# solar pv methods associated with AggregateDataService (see aggregation_service.rb)
class AggregateDataServiceSolar
  include Logging
  include AggregationMixin

  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @heat_meters        = @meter_collection.heat_meters
    @electricity_meters = @meter_collection.electricity_meters
  end

  def process_solar_pv_electricity_meters
    electricity_meters_only = @electricity_meters.select{ |meter| meter.fuel_type == :electricity }

    processed_electricity_meters = electricity_meters_only.map do |mains_electricity_meter|
      if mains_electricity_meter.solar_pv_panels?
        pv_meter_map = setup_meter_map(mains_electricity_meter)
        process_solar_pv_electricity_meter(pv_meter_map)
      else
        mains_electricity_meter
      end
    end

    processed_electricity_meters
  end

  private

  def process_solar_pv_electricity_meter(pv_meter_map)
    log "Aggregation service: processing mains meter #{pv_meter_map[:mains_consume].to_s} with solar pv"

    clean_pv_meter_start_and_end_dates(pv_meter_map)

    create_solar_pv_sub_meters_using_sheffield_pv_estimates(pv_meter_map) if pv_meter_map[:generation].nil?
    
    print_meter_map(pv_meter_map)

    fill_in_missing_real_meter_data_with_data_from_sheffield_university(pv_meter_map)
    
    create_export_and_calculate_self_consumption_meters(pv_meter_map)
    
    create_mains_plus_self_consume_meter(pv_meter_map)

    raise EnergySparksUnexpectedStateException, 'Not all solar pv meters assigned' if pv_meter_map.values.any?(&:nil?)
    
    assign_meter_names(pv_meter_map)

    calculate_carbon_emissions_and_costs(pv_meter_map)

    mains_plus_self_consume_meter = assign_meters_and_sub_meters(pv_meter_map)

    print_meter_map(pv_meter_map)
    print_final_setup(mains_plus_self_consume_meter)

    mains_plus_self_consume_meter
  end

  # keeps track of available meters; eventually help move into separate class
  def empty_meter_map
    {
      export:                   nil,
      generation:               nil,
      self_consume:             nil,
      mains_consume:            nil,
      mains_plus_self_consume:  nil
    }
  end

  def print_meter_map(pv_meter_map)
    log 'PV Meter map:'
    pv_meter_map.each do |meter_type, meter|
      log "    #{meter_type} => #{meter.to_s} total #{meter.nil? ? nil : meter.amr_data.total.round(0)}"
    end
  end

  def print_final_setup(meter)
    log "Final meter setup for #{meter.to_s} total #{meter.amr_data.total.round(0)}"
    meter.sub_meters.each do |meter_type, sub_meter|
      log "    sub_meter: #{meter_type} => #{sub_meter.to_s} name #{sub_meter.name} total #{sub_meter.amr_data.total.round(0)}"
    end
  end

  def log(str)
    logger.info str
    puts str # comment out for release to production
  end

  def clean_pv_meter_start_and_end_dates(pv_meter_map)
    backfill_existing_meters_with_zeros(pv_meter_map)
    truncate_to_mains_meter_dates(pv_meter_map)
  end

  def create_synthetic_solar_pv_generation_data_from_sheffield_university(pv_meter_map)
    pv_meter_map[:generation] = create_synthetic_generation_submeter(pv_meter_map[:mains_consume])
  end

  def fill_in_missing_real_meter_data_with_data_from_sheffield_university(pv_meter_map)
    # TODO: iterate through an sheffield pv meter attributes on generation meter
    #       and fill in any missing data - applies to real generation meters only
    #       but this is implicit based on the attributes(s) being set on the generation meter
  end

  def negate_sign_of_export_meter_data(pv_meter_map)
    pv_meter_map[:export].amr_data = invert_export_amr_data_if_positive(pv_meter_map[:export].amr_data)
  end

  def create_export_and_calculate_self_consumption_meters(pv_meter_map)
    if pv_meter_map[:export].nil?
      create_export_meter(pv_meter_map) if pv_meter_map[:export].nil?
    else
      negate_sign_of_export_meter_data(pv_meter_map)
    end
    create_and_calculate_self_consumption_meter(pv_meter_map) if pv_meter_map[:self_consume].nil?
  end

  def create_export_meter(pv_meter_map)
  end

  def create_and_calculate_self_consumption_meter(pv_meter_map)
    # take the mains consumption, export and solar pv production
    # meter readings and calculate self consumption =
    # self_consumption = solar pv production - export
    onsite_consumpton_amr_data = aggregate_amr_data(
      [pv_meter_map[:generation], pv_meter_map[:export]],
      :electricity
      )

    make_all_amr_data_positive(onsite_consumpton_amr_data)

    pv_meter_map[:self_consume] = solar_pv_consumed_onsite_meter = create_modified_meter_copy(
      pv_meter_map[:mains_consume],
      onsite_consumpton_amr_data,
      :solar_pv,
      Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :solar_pv),
      SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
      :solar_pv_consumed_sub_meter
    )
  end

  def create_mains_plus_self_consume_meter(pv_meter_map)
    consumpton_amr_data = aggregate_amr_data(
      [pv_meter_map[:self_consume], pv_meter_map[:mains_consume]],
      :electricity
      )

    pv_meter_map[:mains_plus_self_consume] = create_modified_meter_copy(
      pv_meter_map[:mains_consume],
      consumpton_amr_data,
      :electricity,
      pv_meter_map[:mains_consume].mpan_mprn,
      pv_meter_map[:mains_consume].name,
      {}
    )
  end

  def calculate_carbon_emissions_and_costs(pv_meter_map)
    pv_meter_map.values.each do |meter|
      calculate_meter_carbon_emissions_and_costs(meter, :electricity)
    end
  end

  def assign_meters_and_sub_meters(pv_meter_map)
    %i[mains_consume self_consume export generation].each do |meter_type|
      pv_meter_map[:mains_plus_self_consume].sub_meters[meter_type] = pv_meter_map[meter_type]
    end
    pv_meter_map[:mains_plus_self_consume]
  end

  def assign_meter_names(pv_meter_map)
    pv_meter_map.each do |meter_type, meter|
      meter.name = meter_type_to_name_map[meter_type]
    end
  end

  def meter_type_to_name_map
    {
      export:                   SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
      generation:               SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      self_consume:             SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
      mains_consume:            SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
      mains_plus_self_consume:  SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
    }
  end

  def make_all_amr_data_positive(amr_data)
    # TODO - potential for export to exceed production if metering issue
    # e.g. timing of different sources for meter
  end

  def backfill_existing_meters_with_zeros(pv_meter_map)
    pv_meter_map.each do |meter_type, meter|
      next if meter.nil? || meter_type == :mains_consume
      mpan_mapping_start_date = earliest_mpan_mapping_attribute(pv_meter_map[:mains_consume], meter_type)
puts "earliest date #{mpan_mapping_start_date}"
      mains_meter_start_date  = pv_meter_backfill_start_date(pv_meter_map[:mains_consume])
      start_date = [mpan_mapping_start_date, mains_meter_start_date].min
      backfill_meter_with_zeros(meter, start_date, mpan_mapping_start_date)
    end
  end

  def truncate_to_mains_meter_dates(pv_meter_map)
    mains_electricity_meter = pv_meter_map[:mains_consume]
    pv_meter_map.each do |meter_type, meter|
      next if meter.nil? || meter_type == :mains_consume
      raise EnergySparksUnexpectedStateException, "Meter should have been backfilled to #{mains_electricity_meter.amr_data.start_date} but set to #{meter.amr_data.start_date}" if mains_electricity_meter.amr_data.start_date > meter.amr_data.start_date
      if meter.amr_data.start_date < mains_electricity_meter.amr_data.start_date
        log "Truncating meter #{meter.mpan_mprn} to start date of electricity meter #{mains_electricity_meter.amr_data.start_date}"
        meter.amr_data.set_start_date(mains_electricity_meter.amr_data.start_date)
      end
      if meter.amr_data.end_date > mains_electricity_meter.amr_data.end_date
        log "Truncating meter #{meter.mpan_mprn} to end date of electricity meter #{mains_electricity_meter.amr_data.start_date}"
        meter.amr_data.set_end_date(mains_electricity_meter.amr_data.end_date)
      end
    end
  end

  def pv_meter_backfill_start_date(mains_electricity_meter)
    mains_electricity_meter.amr_data.start_date
  end

  def create_synthetic_generation_submeter(electricity_meter)
    mpan_solar_pv = Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.mpan_mprn, :solar_pv)
    pv_amr = electricity_meter.solar_pv_setup.create_solar_pv_production_amr_from_sheffield_university(electricity_meter.amr_data, @meter_collection, mpan_solar_pv)
    solar_pv_meter = create_modified_meter_copy(
      electricity_meter,
      pv_amr,
      :solar_pv,
      mpan_solar_pv,
      SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      :solar_pv_sub_meter
    )
    solar_pv_meter
  end

  # creates artificial PV meters, if solar pv present by scaling
  # 1/2 hour yield data from Sheffield University by the kWp(s) of
  # the PV installation; note the kWh is negative as its a producer
  # rather than a consumer
  def create_solar_pv_sub_meters_using_sheffield_pv_estimates(pv_map)
    log 'Creating solar PV data from Sheffield PV feed'

    print_meter_map(pv_map)

    electricity_meter = pv_map[:mains_consume]

    log 'Creating an artificial solar pv meter and associated amr data'

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

    pv_map[:self_consume] = solar_pv_meter

    exported_pv = create_modified_meter_copy(
      electricity_meter,
      disaggregated_data[:exported],
      :solar_pv,
      Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :exported_solar_pv),
      SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
      :solar_pv_exported_sub_meter
    )
    log "Created meter exported data from #{disaggregated_data[:exported].start_date} to #{disaggregated_data[:exported].end_date} #{disaggregated_data[:exported].total.round(0)}kWh"

    pv_map[:export] = exported_pv

    pv_generation_meter = create_modified_meter_copy(
      electricity_meter,
      disaggregated_data[:solar_pv_output],
      :solar_pv,
      Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.mpan_mprn, :solar_pv),
      SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      :solar_pv
    )
    log "Created meter generation data from #{disaggregated_data[:solar_pv_output].start_date} to #{disaggregated_data[:solar_pv_output].end_date} #{disaggregated_data[:solar_pv_output].total.round(0)}kWh"

    pv_map[:generation] = pv_generation_meter

    # make the original top level meter a sub meter of itself

    original_electric_meter = create_modified_meter_copy(
      electricity_meter,
      electricity_meter.amr_data,
      :electricity,
      electricity_meter.id,
      SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
      :solar_pv_original_sub_meter
    )

    log "Making original mains consumption meter a submeter from #{electricity_meter.amr_data.start_date} to #{electricity_meter.amr_data.end_date} #{electricity_meter.amr_data.total.round(0)}kWh"

    pv_map[:mains_consume] = original_electric_meter

    # replace the AMR data of the top level meter with the
    # combined original mains consumption data plus the solar pv data
    # currently the updated meter inherits the carbon emissions and costs of the original
    # which implies the solar pv is zero carbon and zero cost
    # a full accounting treatment will need to deal with FITs and exports..... TODO(PH, 7Apr2019)

    electricity_meter.amr_data = disaggregated_data[:electricity_consumed_onsite]
    electricity_meter.id       = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
    electricity_meter.name     = SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV

    pv_map[:mains_plus_self_consume] = electricity_meter
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

  # the mpan mapping is used to override the start date of the incoming data
  # if necessary e.g. in the circumstance where the metering was incorrect
  # during the installation phase, so anything before that is deemed to be
  # zero, or overridden by the synthetic Sheffield data if set
  def earliest_mpan_mapping_attribute(mains_meter, meter_type)
    mains_meter.attributes(:solar_pv_mpan_meter_mapping).map do |mpan_pv_map|
      mpan_pv_map[meter_type_attribute_map(meter_type)].nil? ? nil : meter_start_date(mpan_pv_map)
    end.compact.min
  end

  def meter_start_date(mpan_pv_map)
    if mpan_pv_map[:start_date].nil?
      # TODO(PH, 18Nov2020) - legacy, remove once now mandatory mapping :start_date set
      mapped_meters = MPAN_KEY_MAPPINGS.values.compact.map do |type|
        @electricity_meters.detect{ |m| m.mpan_mprn.to_s == mpan_pv_map[type] }
      end.compact
      mapped_meters.map{ |meter| meter.amr_data.start_date }.max
    else
      mpan_pv_map[:start_date]
    end
  end

  # to save endless checking downstream in the analysis code
  # backfill pv meters which don't extend backwards as far as the
  # mains electricity meter with zeros
  def backfill_meter_with_zeros(meter, mains_meter_start_date, mpan_mapping_start_date)
    return if mains_meter_start_date >= meter.amr_data.start_date
    log "Backfilling pv meter #{meter.mpan_mprn} with zeros between #{mains_meter_start_date} and #{meter.amr_data.start_date}"
    (mains_meter_start_date..meter.amr_data.start_date).each do |date|
      meter.amr_data.add(date, OneDayAMRReading.zero_reading(meter.id, date, 'BKPV'))
    end
  end

  # find and map all known pv related pv meters
  def setup_meter_map(mains_electricity_meter)
    pv_meter_map = empty_meter_map
    pv_meter_map[:mains_consume] = mains_electricity_meter
    map_real_meters(pv_meter_map)
    pv_meter_map
  end

  # check to see whether any real pv meters exist
  # and add them to the map, removing them from the meter collection
  # so they can eventual become sub meters of the electricity meter
  def map_real_meters(pv_meter_map)
    mappings = pv_meter_map[:mains_consume].attributes(:solar_pv_mpan_meter_mapping)
    return if mappings.nil?
    mappings.each do |map|
      mpan_maps(map).each do |meter_type, mpan|
        meter = @meter_collection.electricity_meters.find{ |meter1| meter1.mpan_mprn.to_s == mpan }
        @meter_collection.electricity_meters.delete_if { |meter| meter.mpan_mprn.to_s == mpan.to_s }
        pv_meter_map[attribute_map_meter_type(meter_type)] = meter
      end
    end
    print_meter_map(pv_meter_map)
  end

  MPAN_KEY_MAPPINGS = {
    export_mpan:      :export,
    production_mpan: :generation
  }
  def mpan_maps(mpan_map)
    mpan_map.select {|k,_v| MPAN_KEY_MAPPINGS.keys.include?(k)}
  end

  def attribute_map_meter_type(mpan_meter_type)
    MPAN_KEY_MAPPINGS[mpan_meter_type]
  end

  def meter_type_attribute_map(meter_type)
    MPAN_KEY_MAPPINGS.key(meter_type)
  end
end

class OldPVProcessingCodeDeprecated
  # ==========================================================================================

  def process_solar_pv_electricity_meters_deprecated
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

    log "Totals: pv #{solar_meter.amr_data.total} exp #{export_meter.amr_data.total} mains #{mains_meter.amr_data.total} pvons #{solar_pv_consumed_onsite_meter.amr_data.total}"
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
        meter = @meter_collection.electricity_meters.find{ |meter1| meter1.mpan_mprn.to_s == mpan }
        @meter_collection.electricity_meters.delete_if{ |meter1| meter1.mpan_mprn.to_s == mpan }
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
    mains_meters = @meter_collection.electricity_meters.select{ |meter| meter.fuel_type == :electricity }
    mains_meters.map do |mains_meter|
      [
        mains_meter,
        mains_meter.attributes(:solar_pv_mpan_meter_mapping)
      ]
    end.select{ |meter| !meter[1].nil? }
  end
end