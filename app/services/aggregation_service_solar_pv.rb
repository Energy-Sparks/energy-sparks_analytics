# frozen_string_literal: true

# solar pv methods associated with AggregateDataService (see aggregation_service.rb)
class AggregateDataServiceSolar
  include Logging
  include AggregationMixin

  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @electricity_meters = @meter_collection.electricity_meters
    @electricity_meter_names = find_electricity_meter_names
  end

  def process_solar_pv_electricity_meters
    log '=' * 80
    electricity_meters_only = @electricity_meters.select { |meter| meter.fuel_type == :electricity }

    processed_electricity_meters = electricity_meters_only.map do |mains_electricity_meter|
      if mains_electricity_meter.solar_pv_panels?
        pv_meter_map = setup_meter_map(mains_electricity_meter)
        process_solar_pv_electricity_meter(pv_meter_map)
      else
        reference_as_sub_meter_for_subsequent_aggregation(mains_electricity_meter)
        mains_electricity_meter
      end
    end
    log '=' * 80
    processed_electricity_meters
  end

  def backfill_meters_with_zeros(meters, mains_meter_start_date)
    meters.each do |meter|
      backfill_meter_with_zeros(meter, mains_meter_start_date, meter.amr_data.start_date - 1)
    end
  end

  private

  def find_electricity_meter_names
    @electricity_meters.map { |electricity_meter| [electricity_meter.mpan_mprn, electricity_meter.name] }.to_h
  end

  def process_solar_pv_electricity_meter(pv_meter_map)
    log "Aggregation service: processing mains meter #{pv_meter_map[:mains_consume]} with solar pv"
    print_meter_map(pv_meter_map)

    aggregate_multiple_generation_meters(pv_meter_map) if pv_meter_map.number_of_generation_meters > 1

    if !pv_meter_map[:generation].nil? && pv_meter_map[:export].nil?
      create_export_self_consumption_where_real_generation_data_but_no_export(pv_meter_map)
    elsif pv_meter_map[:mains_consume].sheffield_simulated_solar_pv_panels?
      create_solar_pv_sub_meters_using_sheffield_pv_estimates(pv_meter_map)
    else
      clean_pv_meter_start_and_end_dates(pv_meter_map)

      create_export_and_calculate_self_consumption_meters(pv_meter_map)

      fix_missing_or_bad_meter_data(pv_meter_map)
    end

    create_mains_plus_self_consume_meter(pv_meter_map)

    unless pv_meter_map.all_required_key_values_non_nil?
      raise EnergySparksUnexpectedStateException, 'Not all solar pv meters assigned'
    end

    assign_meter_names(pv_meter_map)

    calculate_carbon_emissions_and_costs(pv_meter_map)

    normalise_date_ranges_of_sub_meters(pv_meter_map)
    mains_plus_self_consume_meter = assign_meters_and_sub_meters(pv_meter_map)

    consumption_meter = mains_plus_self_consume_meter

    print_meter_map(pv_meter_map)
    print_final_setup(mains_plus_self_consume_meter)

    consumption_meter
  end

  def fix_missing_or_bad_meter_data(pv_meter_map)
    if !pv_meter_map[:mains_consume].nil? && !pv_meter_map[:mains_consume].solar_pv_overrides.nil?
      pv_meter_map[:mains_consume].solar_pv_overrides.process(pv_meter_map, @meter_collection)
    end
  end

  def not_a_meter?(meter)
    meter.nil? || meter.is_a?(Array)
  end

  def print_meter_map(pv_meter_map)
    log 'PV Meter map:'
    pv_meter_map.each do |meter_type, meter|
      if meter.is_a?(Array)
        log "    #{meter_type} => #{meter.map { |m| format_meter(m)}.join('; ')}"
      else
        log "    #{format('%-25.25s', meter_type)} -> #{format_meter(meter)}"
      end
    end
  end

  def format_meter(meter)
    meter.nil? ? 'nil' : "#{format('%-60.60s', meter.to_s)} = #{meter.amr_data.total.round(0)} kWh"
  end

  def print_final_setup(meter)
    log "Final meter setup for #{meter} total #{meter.amr_data.total.round(0)}"
    meter.sub_meters.each do |meter_type, sub_meter|
      log "    sub_meter: #{meter_type} => #{sub_meter} name #{sub_meter.name} total #{sub_meter.amr_data.total.round(0)}"
    end
  end

  def log(str)
    logger.info str
    # puts str # "Got here" # comment out for release to production
  end

  def reference_as_sub_meter_for_subsequent_aggregation(mains_electricity_meter)
    log 'Referencing mains consumption meter {mains_electricity_meter.mpan_mprn} without pv as sub meter for subsequent aggregation'
    mains_electricity_meter.sub_meters[:mains_consume] = mains_electricity_meter
  end

  def clean_pv_meter_start_and_end_dates(pv_meter_map)
    backfill_existing_meters_with_zeros(pv_meter_map)
    truncate_to_mains_meter_dates(pv_meter_map)
  end

  def negate_sign_of_export_meter_data(pv_meter_map)
    pv_meter_map[:export].amr_data = invert_export_amr_data_if_positive(pv_meter_map[:export].amr_data)
  end

  def create_export_and_calculate_self_consumption_meters(pv_meter_map)
    if pv_meter_map[:export].nil?
      create_export_meter(pv_meter_map)
    else
      negate_sign_of_export_meter_data(pv_meter_map)
    end
    create_and_calculate_self_consumption_meter(pv_meter_map) if pv_meter_map[:self_consume].nil?
  end

  # TODO(PH, 20Nov2020) - untested
  def create_export_meter(pv_meter_map)
    date_range = pv_meter_map[:mains_consume].amr_data.date_range
    log "Creating empty export meter between #{date_range.first} and #{date_range.last}"
    amr_data = AMRData.create_empty_dataset(:exported_solar_pv, date_range.first, date_range.last, 'SOLE')
    create_modified_meter_copy(
      pv_meter_map[:mains_consume],
      amr_data,
      :exported_solar_pv,
      Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, :exported_solar_pv),
      SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
      :solar_pv_exported_sub_meter
    )
  end

  def create_and_calculate_self_consumption_meter(pv_meter_map)
    log 'Creating and calculating self consumption meter'
    # take the mains consumption, export and solar pv production
    # meter readings and calculate self consumption =
    # self_consumption = solar pv production - export
    onsite_consumpton_amr_data = aggregate_amr_data(
      [pv_meter_map[:generation], pv_meter_map[:export]],
      :electricity,
      true
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
      :electricity,
      true
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

  def aggregate_multiple_generation_meters(pv_meter_map)
    log 'Aggregating multiple solar pv generation meters'

    generation_meters = pv_meter_map.select { |type, meter| PVMap.generation_meters.include?(type) && !meter.nil? }.values

    log "Aggregating these generation meters #{generation_meters.map(&:to_s).join(' + ')}"

    mpan = Dashboard::Meter.synthetic_aggregate_generation_meter(pv_meter_map[:generation].mpan_mprn)

    generation_amr_data = aggregate_amr_data_between_dates(
      generation_meters,
      :solar_pv,
      generation_meters.map { |m| m.amr_data.start_date }.min,
      generation_meters.map { |m| m.amr_data.end_date }.max,
      mpan
    )

    generation_meter = create_modified_meter_copy(
      pv_meter_map[:generation],
      generation_amr_data,
      :solar_pv,
      mpan,
      pv_meter_map[:generation].name,
      {}
    )

    log "Created aggregate generation meter #{generation_meter} #{generation_meter.amr_data.total.round(0)}"

    # hide constituent generation meters
    pv_meter_map.set_nil_value(PVMap.generation_meters)
    generation_mpans = generation_meters.map { |m1| m1.mpan_mprn.to_s}
    @meter_collection.electricity_meters.delete_if { |m| generation_mpans.include?(m.mpan_mprn.to_s) }
    pv_meter_map[:generation] = generation_meter
    pv_meter_map[:generation_meter_list] = generation_meters
  end

  def calculate_carbon_emissions_and_costs(pv_meter_map)
    pv_meter_map.each_value do |meter|
      calculate_meter_carbon_emissions_and_costs(meter, :electricity) unless not_a_meter?(meter)
    end
  end

  def normalise_date_ranges_of_sub_meters(pv_meter_map)
    meters = %i[mains_consume self_consume export generation mains_plus_self_consume].map { |meter_type| pv_meter_map[meter_type] }
    start_date = meters.map { |m| m.amr_data.start_date }.max
    end_date   = meters.map { |m| m.amr_data.end_date }.min
    log "Reducing sub meter date ranges to between #{start_date} and #{end_date}"
    meters.each do |meter|
      meter.amr_data.set_start_date(start_date)
      meter.amr_data.set_end_date(end_date)
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
      next if not_a_meter?(meter)

      if meter_type == :mains_plus_self_consume
        school_meter_name = @electricity_meter_names[meter.mpan_mprn]
        meter.name = if school_meter_name.present?
                       I18n.t('aggregation_service_solar_pv.mains_plus_self_consume_name', meter_name: school_meter_name) + " (#{meter.mpan_mprn})"
                     else
                       I18n.t('aggregation_service_solar_pv.mains_plus_self_consume_name', meter_name: meter.mpan_mprn.to_s)
                     end
      else
        meter.name = PVMap.meter_type_to_name_map[meter_type]
      end
    end
  end

  def make_all_amr_data_positive(amr_data)
    # TODO(PH, 20Nov2020) - potential for export to exceed production if metering issue
    # e.g. timing of different sources for meter
  end

  def backfill_existing_meters_with_zeros(pv_meter_map)
    pv_meter_map.each do |meter_type, meter|
      next if not_a_meter?(meter) || meter_type == :mains_consume

      mpan_mapping_start_date = earliest_mpan_mapping_attribute(pv_meter_map[:mains_consume], meter_type)
      mains_meter_start_date  = pv_meter_backfill_start_date(pv_meter_map[:mains_consume])
      backfill_meter_with_zeros(meter, mains_meter_start_date, mpan_mapping_start_date - 1)
    end
  end

  def truncate_to_mains_meter_dates(pv_meter_map)
    mains_electricity_meter = pv_meter_map[:mains_consume]
    pv_meter_map.each do |meter_type, meter|
      next if not_a_meter?(meter) || meter_type == :mains_consume

      log "Mains meter start date #{mains_electricity_meter.amr_data.start_date} pv meter #{meter.mpan_mprn} #{meter.fuel_type} start date #{meter.amr_data.start_date}"
      if mains_electricity_meter.amr_data.start_date < meter.amr_data.start_date
        raise EnergySparksUnexpectedStateException, "Meter should have been backfilled to #{mains_electricity_meter.amr_data.start_date} but set to #{meter.amr_data.start_date}"
      end

      if meter.amr_data.start_date < mains_electricity_meter.amr_data.start_date
        log "Truncating meter #{meter.mpan_mprn} to start date of electricity meter #{mains_electricity_meter.amr_data.start_date}"
        meter.amr_data.set_start_date(mains_electricity_meter.amr_data.start_date)
      end
      if meter.amr_data.end_date > mains_electricity_meter.amr_data.end_date
        log "Truncating meter #{meter.mpan_mprn} to end date of electricity meter #{mains_electricity_meter.amr_data.end_date}"
        meter.amr_data.set_end_date(mains_electricity_meter.amr_data.end_date)
      end
    end
  end

  def pv_meter_backfill_start_date(mains_electricity_meter)
    mains_electricity_meter.amr_data.start_date
  end

  # creates synthetic solar pv metering using 1/2 hour yield data from Sheffield University
  # for schools where we don't have real metering
  def create_solar_pv_sub_meters_using_sheffield_pv_estimates(pv_map)
    log 'Creating solar PV data from Sheffield PV feed'

    pv_map[:mains_consume].solar_pv_setup.process(pv_map, @meter_collection)

    negate_sign_of_export_meter_data(pv_map) # defensive, probably not needed
  end

  def invert_export_amr_data_if_positive(amr_data)
    # using 0.10000000001 as LCC seems to have lots of 0.1 values?????
    histo = amr_data.histogram_half_hours_data([-0.10000000001, +0.10000000001])
    negative = histo[0] > (histo[2] * 10) # 90%
    message = negative ? 'is negative therefore leaving unchanged' : 'is positive therefore inverting to conform to internal convention'
    logger.info "Export amr pv data #{message}"
    amr_data.scale_kwh(-1.0) unless negative
    amr_data
  end

  # the mpan mapping is used to override the start date of the incoming data
  # if necessary e.g. in the circumstance where the metering was incorrect
  # during the installation phase, so anything before that is deemed to be
  # zero, or overridden by the synthetic Sheffield data if set
  def earliest_mpan_mapping_attribute(mains_meter, meter_type)
    mains_meter.attributes(:solar_pv_mpan_meter_mapping).map do |mpan_pv_map|
      mpan_pv_map[PVMap.meter_type_attribute_map(meter_type)].nil? ? nil : meter_start_date(mpan_pv_map)
    end.compact.min
  end

  def meter_start_date(mpan_pv_map)
    if mpan_pv_map[:start_date].nil?
      # TODO(PH, 18Nov2020) - legacy, remove once now mandatory mapping :start_date set
      mapped_meters = PVMap::MPAN_KEY_MAPPINGS.values.compact.map do |type|
        @electricity_meters.detect { |m| m.mpan_mprn.to_s == mpan_pv_map[type] }
      end.compact
      mapped_meters.map { |meter| meter.amr_data.start_date }.max
    else
      mpan_pv_map[:start_date]
    end
  end

  # to save endless checking downstream in the analysis code
  # backfill pv meters which don't extend backwards as far as the
  # mains electricity meter with zeros
  def backfill_meter_with_zeros_deprecated(meter, mains_meter_start_date, _mpan_mapping_start_date)
    return if mains_meter_start_date >= meter.amr_data.start_date

    log "Backfilling pv meter #{meter.mpan_mprn} with zeros between #{mains_meter_start_date} and #{meter.amr_data.start_date}"
    (mains_meter_start_date..meter.amr_data.start_date).each do |date|
      meter.amr_data.add(date, OneDayAMRReading.zero_reading(meter.id, date, 'BKPV'))
    end
  end

  # to save endless checking downstream in the analysis code
  # backfill pv meters which don't extend backwards as far as the
  # mains electricity meter with zeros
  def backfill_meter_with_zeros(meter, start_date, end_date)
    return if start_date >= meter.amr_data.start_date

    log "Backfilling pv meter #{meter.mpan_mprn} with zeros between #{start_date} and #{end_date}"
    (start_date..end_date).each do |date|
      meter.amr_data.add(date, OneDayAMRReading.zero_reading(meter.id, date, 'BKPV'))
    end
  end

  # find and map all known pv related pv meters
  def setup_meter_map(mains_electricity_meter)
    pv_meter_map = PVMap.instance
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
      PVMap.mpan_maps(map).each do |meter_type, mpan|
        meter = @meter_collection.electricity_meters.find { |meter1| meter1.mpan_mprn.to_s == mpan }
        @meter_collection.electricity_meters.delete_if { |m| m.mpan_mprn.to_s == mpan.to_s }
        pv_meter_map[PVMap.attribute_map_meter_type(meter_type)] = meter
        truncate_meter_dates(meter, map)
      end
    end
  end

  def truncate_meter_dates(meter, map)
    truncate_start_date(meter, map[:start_date])
    truncate_end_date(meter, map[:end_date])
  end

  def create_export_self_consumption_where_real_generation_data_but_no_export(pv_meter_map)
    am = pv_meter_map[:generation].amr_data

    if @apply_scaling_factor_for_debug
      scale_factor = 1.0
      puts '*' * 50
      puts "Scaling data by a factor of #{scale_factor} "
      pv_meter_map[:generation].amr_data.scale_kwh(scale_factor, date1: am.start_date, date2: am.end_date)
      puts '*' * 50
    end

    # real generation data but no export, so calculate
    SolarPVPanelsMeteredProduction.new.process(pv_meter_map, @meter_collection)

    truncate_to_mains_meter_dates(pv_meter_map)

    # potentially override or extend with Sheffield Synthetic
    if pv_meter_map[:mains_consume].sheffield_simulated_solar_pv_panels?
      create_solar_pv_sub_meters_using_sheffield_pv_estimates(pv_meter_map)
    end

    # and with solar override attributes as well
    fix_missing_or_bad_meter_data(pv_meter_map)
  end

  def truncate_start_date(meter, start_date)
    return if start_date.nil?

    if start_date < meter.amr_data.start_date
      log "Error: solar_pv_mpan_meter_mapping meter attribute start_date #{start_date} < meter start_date #{meter.amr_data.start_date}"
    elsif start_date > meter.amr_data.end_date
      log "Error: solar_pv_mpan_meter_mapping meter attribute start_date #{start_date} > meter end_date #{meter.amr_data.end_date}"
    else
      log "Warning: overriding amr start date to #{start_date} for meter #{meter.mpan_mprn}"
      meter.amr_data.set_start_date(start_date)
    end
  end

  def truncate_end_date(meter, end_date)
    return if end_date.nil?

    if end_date > meter.amr_data.end_date
      log "Error: solar_pv_mpan_meter_mapping meter attribute end_date #{end_date} > meter end_date #{meter.amr_data.end_date}"
    elsif end_date < meter.amr_data.start_date
      log "Error: solar_pv_mpan_meter_mapping meter attribute end_date #{end_date} < meter start_date #{meter.amr_data.start_date}"
    else
      log "Warning: overriding amr end date to #{end_date} for meter #{meter.mpan_mprn}"
      meter.amr_data.set_end_date(end_date)
    end
  end
end
