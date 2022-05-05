# Electricity meters with storage heaters are flagged by the presence of a
# storage heater meter attribute on the meter.
#
# Where the meter also have appliance comsumption
# synthetically split the meter into 2 meters: 1. storage heaters 2. the rest/appliances
#
# where there are multiple electricity meters, the sh meter, the appliance meter and the original meter
# are then aggregated seperately, so there are aggregate versions of each
#
class SHMap < RestrictedKeyHash
  def self.unique_keys; %i[original storage_heater ex_storage_heater] end
end

class AggregateDataServiceStorageHeaters
  include Logging
  include AggregationMixin

  attr_reader :meter_collection

  def initialize(meter_collection)
    @meter_collection   = meter_collection
    @electricity_meters = @meter_collection.electricity_meters
    @debug = false
  end

  def disaggregate
    log('=' * 100)
    log("Disaggregating storage heater meters for #{@meter_collection.name}: #{@electricity_meters.length} electricity meters")

    bm = Benchmark.realtime {
      reworked_meter_maps = disaggregate_meters
      
      calculate_meters_carbon_emissions_and_costs(reworked_meter_maps)

      summarise_maps(reworked_meter_maps) if @debug

      aggregate = if @electricity_meters.length > 1
                    aggregate_meters(reworked_meter_maps)
                  else
                    reworked_meter_maps[0]
                  end
      
      assign_aggregate(aggregate)
    }

    summarise_aggregated_meter
    summarise_component_meters

    log("Disaggregation of storage heater meters for #{@meter_collection.name} complete in #{bm.round(3)} seconds")
    log('=' * 100)
  end

  private

  def disaggregate_meters
    @electricity_meters.map.with_index do |electricity_meter, i|
      if electricity_meter.storage_heater?
        map = disaggregate_storage_heat_meter(electricity_meter)
        @electricity_meters[i] = reassign_meters(map)
        map
      else
        map = SHMap.new
        map[:original]          = electricity_meter
        map[:ex_storage_heater] = electricity_meter
        map
      end
    end
  end

  def assign_aggregate(meter_map)
    reassign_meters(meter_map)
    @meter_collection.aggregated_electricity_meters = meter_map[:ex_storage_heater]
    @meter_collection.storage_heater_meter = meter_map[:storage_heater]
  end

  def disaggregate_storage_heat_meter(meter)
    map = SHMap.new
    map[:original] = meter

    electric_only_amr, storage_heater_amr = meter.storage_heater_setup.disaggregate_amr_data(meter.amr_data, meter.mpan_mprn)

    map[:storage_heater]    = create_meter(meter, storage_heater_amr, :storage_heater_disaggregated_storage_heater, :storage_heater)
    map[:ex_storage_heater] = create_meter(meter, electric_only_amr,  :storage_heater_disaggregated_electricity)
    map
  end

  def summarise_aggregated_meter
    log('Aggregated Meter Setup')
    log("    appliance: #{aggregate_meter_desciption(@meter_collection.aggregated_electricity_meters)}")
    log("    storage:   #{aggregate_meter_desciption(@meter_collection.storage_heater_meter)}")
    log("    original:  #{aggregate_meter_desciption(@meter_collection.aggregated_electricity_meters.sub_meters[:mains_consume])}")
  end

  def aggregate_meter_desciption(meter)
    sprintf('%60.60s: %9.0f kWh', meter.to_s, meter.amr_data.total)
  end

  def summarise_component_meters
    log('Component Meter Setup')
    @meter_collection.electricity_meters.each.with_index do |meter, i|
      log("    Meter #{i}")
      log(sprintf('        %-18.18s %s', 'ex storage heater', meter_description(meter)))
      log(sprintf('        %-18.18s %s', 'original',          meter_description(meter.sub_meters[:mains_consume])))
      log(sprintf('        %-18.18s %s', 'storage heaters',   meter_description(meter.sub_meters[:storage_heaters])))
    end
  end

  # replace the original mains meter, with the mains meter ex storage heaters
  # asign the original and the storage heater only meters as sub meters
  def reassign_meters(map)
    map[:ex_storage_heater].sub_meters.merge!(map[:original].sub_meters) # merge in solar meters
    map[:ex_storage_heater].sub_meters[:mains_consume]   = map[:original]
    map[:ex_storage_heater].sub_meters[:storage_heaters] = map[:storage_heater]
    map[:ex_storage_heater]
  end

  def aggregate_meters(meter_maps)
    aggregate_map = SHMap.new
    meter_maps.each do |meter_map|
      meter_map.each do |type, meter|
        next if meter.nil?
        aggregate_map[type] ||= []
        aggregate_map[type].push(meter)
      end
    end

    aggregated_amr_data = aggregate_map.transform_values do |meters|
      aggregate_amr_data(meters, :electricity)
    end

    aggregated_meter_map = SHMap.new
    type_map = { 
      storage_heater:     :storage_heater_disaggregated_storage_heater,
      ex_storage_heater:  :storage_heater_disaggregated_electricity,
      original:           :aggregated_electricity
    }
    aggregated_amr_data.each do |type, amr_data|
      fuel_type = type == :storage_heater ? :storage_heater : :electricity
      aggregated_meter_map[type] = create_meter(aggregate_map[type][0], amr_data, type_map[type], fuel_type)
    end

    calculate_carbon_emissions_and_costs(aggregated_meter_map)

    if @debug
      log('Aggregated meters breakdown:')
      summarise_map(aggregated_meter_map)
    end
    aggregated_meter_map
  end

  def summarise_maps(maps)
    maps.each do |map|
      log("Storage heater breakdown for #{map[:original]}")
      summarise_map(map)
    end
  end

  def summarise_map(map)
    map.each do |type, meter|
      log(sprintf('    %-18.18s %s', type.to_s, meter_description(meter)))
    end
  end

  def meter_description(meter)
    meter.nil? ? '' : sprintf('%14.14s %.0f kWh', meter.mpxn, meter.amr_data.total)
  end

  def create_meter(meter, amr_data, meter_type, fuel_type = :electricity)
    new_meter = create_modified_meter_copy(
      meter,
      amr_data,
      fuel_type,
      meter.id,
      meter.name + ' ' + meter_type.to_s.humanize,
      meter_type
    )

    set_synthetic_mpan(new_meter, meter, meter_type)

    new_meter
  end

  def set_synthetic_mpan(new_meter, original_meter, meter_type)
    if meter_type == :aggregated_electricity
      new_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(@meter_collection.urn, meter_type))
    else
      new_meter.set_mpan_mprn_id(Dashboard::Meter.synthetic_mpan_mprn(original_meter.id, meter_type))
    end
  end

  def calculate_meters_carbon_emissions_and_costs(maps)
    maps.each do |map|
      calculate_carbon_emissions_and_costs(map)
    end
  end

  def calculate_carbon_emissions_and_costs(map)
    map.each_value do |meter|
      next if meter.nil?
      calculate_meter_carbon_emissions_and_costs(meter, :electricity)
    end
  end

  def log(str)
    logger.info str

    puts str if @debug
  end
end
