module AggregationMixin
  private def create_modified_meter_copy(meter, amr_data, type, identifier, name, pseudo_meter_name, meter_type = Dashboard::Meter )
    meter_type.new(
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

  private def create_aggregate_meter(aggregate_meter, meters, fuel_type, identifier, name, pseudo_meter_name)
    aggregate_amr_data = aggregate_amr_data_between_dates(meters, fuel_type, aggregate_meter.amr_data.start_date, aggregate_meter.amr_data.end_date, aggregate_meter.mpxn)

    new_aggregate_meter = create_modified_meter_copy(aggregate_meter, aggregate_amr_data, fuel_type, identifier, name, pseudo_meter_name, Dashboard::AggregateMeter)

    new_aggregate_meter.set_constituent_meters(meters)

    calculate_meter_carbon_emissions_and_costs(new_aggregate_meter, fuel_type)

    new_aggregate_meter
  end

  private def aggregate_amr_data(meters, type, ignore_rules = false)
    if meters.length == 1
      logger.info "Single meter, so aggregation is a reference to itself not an aggregate meter"
      return meters.first.amr_data # optimisaton if only 1 meter, then its its own aggregate
    end
    min_date, max_date = combined_amr_data_date_range(meters, ignore_rules)

    #This can happen if there are 2 meter, with non-overlapping date ranges
    #Without a check, the renaming code is run but we end up with an aggregate meter that
    #contains no readings and has default dates from HalfHourlyData.new. This can cause errors elsewhere as other
    #code does not check for the dates or if there are no readings.
    raise EnergySparksUnexpectedStateException.new("Invalid AMR date range. Minimum date (#{min_date}) after maximum date (#{max_date}) unable to aggregate data") if min_date > max_date

    logger.info "Aggregating data between #{min_date} and #{max_date}"

    mpan_mprn = Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, meters[0].fuel_type) unless @meter_collection.urn.nil?

    combined_amr_data = aggregate_amr_data_between_dates(meters, type, min_date, max_date, mpan_mprn)
  end

  def aggregate_amr_data_between_dates(meters, type, start_date, end_date, mpan_mprn)
    combined_amr_data = AMRData.new(type)
    (start_date..end_date).each do |date|
      valid_meters_for_date = meters.select { |meter| meter.amr_data.date_exists?(date) }
      amr_data_for_date_x48_valid_meters = valid_meters_for_date.map { |meter| meter.amr_data.days_kwh_x48(date) }
      combined_amr_data_x48 = AMRData.fast_add_multiple_x48_x_x48(amr_data_for_date_x48_valid_meters)
      days_data = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, combined_amr_data_x48)
      combined_amr_data.add(date, days_data)
    end
    combined_amr_data
  end

  # for overlapping data i.e. date range where there is data for all meters
  def combined_amr_data_date_range(meters, ignore_rules)
    if ignore_rules
      combined_amr_data_date_range_no_rules(meters)
    else
      combined_amr_data_date_range_with_rules(meters)
    end
  end

  def combined_amr_data_date_range_no_rules(meters)
    [
      meters.map{ |m| m.amr_data.start_date }.max,
      meters.map{ |m| m.amr_data.end_date   }.min
    ]
  end

  def combined_amr_data_date_range_with_rules(meters)
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

  private def calculate_carbon_emissions_for_meter(meter, fuel_type)
    if fuel_type == :electricity || fuel_type == :aggregated_electricity # TODO(PH, 6Apr19) remove : aggregated_electricity once analytics meter meta data loading changed
      meter.amr_data.set_carbon_emissions(meter.id, nil, @meter_collection.grid_carbon_intensity)
    else
      meter.amr_data.set_carbon_emissions(meter.id, EnergyEquivalences::UK_GAS_CO2_KG_KWH, nil)
    end
  end

  private def calculate_costs_for_meter(meter)
    logger.info "Creating economic & accounting costs for #{meter.mpan_mprn} fuel #{meter.fuel_type} from #{meter.amr_data.start_date} to #{meter.amr_data.end_date}"
    meter.amr_data.set_tariffs(meter)
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
end
