# storage heater methods associated with AggregateDataService (see aggregation_service.rb)
class AggregateDataService
  include Logging

  # if the electricity meter has a storage heater, split the meter
  # into 2 one with storage heater only kwh, the other with the remainder
  private def disaggregate_storage_heaters
    logger.info '=' * 80
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
    logger.info '=' * 80
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
    logger.info "=" * 80
    logger.info "Disaggregating electricity meter #{electricity_meter.mpxn} into 1x storage heater only and 1 x remainder"

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
    electricity_meter.sub_meters[:mains_consume] = original_electricity_meter_copy

    electricity_meter.amr_data = electric_only_amr
    calculate_meter_carbon_emissions_and_costs(electricity_meter, :electricity)

    storage_heater_meter = create_modified_meter_copy(
      electricity_meter,
      storage_heater_amr,
      :storage_heater,
      electricity_meter.id,
      meter_name(electricity_meter.name),
      :storage_heater_disaggregated_storage_heater
    )

    calculate_meter_carbon_emissions_and_costs(storage_heater_meter, :electricity)

    # set the synthetic meter identifier once the tariffs have been assigned above using the real meter identifier
    electricity_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :electricity_minus_storage_heater))
    storage_heater_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(electricity_meter.id, :storage_heater_only))

    proportion_out_accounting_standing_charges(storage_heater_meter, electricity_meter)

    electricity_meter.sub_meters[:storage_heaters] = [storage_heater_meter]

    logger.info "=" * 80

    {
      electricity_minus_storage_heater_meter: electricity_meter,
      storage_heater_meter: storage_heater_meter
    }
  end

  private def meter_name(stub)
    if stub == SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV
      # tidy up meter name so not too long, ignore solar pv wording
      'storage heater charging'
    else
      "#{stub} storage heater charging" 
    end
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
      meter_name(meter_collection.aggregated_electricity_meters.name),
      :storage_heater_aggregated
    )

    calculate_meter_carbon_emissions_and_costs(aggregate_storage_heater_meter, :electricity)

    @meter_collection.storage_heater_meter = aggregate_storage_heater_meter
  end

  private def calculate_aggregated_disaggregated_electricity_meter_for_storage_heater_school(disaggregated_meter_list, non_storage_heater_meters)
    disaggregated_electricity_meters_list = disaggregated_meter_list.map { |h| h[:electricity_minus_storage_heater_meter] }

    original_meter = @meter_collection.aggregated_electricity_meters

    # including the non-storage heater meter data!
    disaggregated_electricity_meters_list += non_storage_heater_meters unless non_storage_heater_meters.empty?

    disaggregated_electricity_amr_data = aggregate_amr_data(
      disaggregated_electricity_meters_list,
      :electricity
    )

    aggregate_electricity_meter = create_modified_meter_copy(
      original_meter, # pass in floor area, pupil numbers
      disaggregated_electricity_amr_data,
      :electricity,
      Dashboard::Meter.synthetic_mpan_mprn(original_meter.id, :electricity_minus_storage_heater),
      "#{original_meter.name} - aggregated non storage heaters consumption",
      :storage_heater_disaggregated_electricity
    )

    aggregate_electricity_meter.sub_meters[:storage_heaters] = disaggregated_meter_list.map { |m| m[:storage_heater_meter] }.flatten
    aggregate_electricity_meter.sub_meters[:mains_consume] = original_meter

    @meter_collection.aggregated_electricity_meters = aggregate_electricity_meter

    calculate_meter_carbon_emissions_and_costs(@meter_collection.aggregated_electricity_meters, :electricity)
  end
end