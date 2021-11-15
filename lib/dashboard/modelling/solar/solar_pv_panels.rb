# creates new solar pv panel data synthetically from Sheffield University sourced data
# and can also use this to override real solar pv metering when it goes wrong via meter attributes
# uses the SolarPV, SolarPVOverrides, SolarPVMeterMapping meter attributes for configuration
class SolarPVPanels
  include Logging
  attr_reader :meter_attributes_config

  MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV = 'Electricity consumed including onsite solar pv consumption'.freeze
  SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME = 'Electricity consumed from solar pv'.freeze
  SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME = 'Exported solar electricity (not consumed onsite)'.freeze
  ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME = 'Electricity consumed from mains'.freeze
  SOLAR_PV_PRODUCTION_METER_NAME = 'Solar PV Production'

  SUBMETER_TYPES = [
    ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
    SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
    SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
  ]

  def initialize(meter_attributes_config, synthetic_sheffield_solar_pv_yields)
    @solar_pv_panel_config = SolarPVPanelConfiguration.new(meter_attributes_config)
    @synthetic_sheffield_solar_pv_yields = synthetic_sheffield_solar_pv_yields
  end

  def first_installation_date
    @solar_pv_panel_config.first_installation_date
  end

  def process(pv_meter_map, meter_collection)
    create_generation_data(pv_meter_map, false)
    create_export_data(pv_meter_map, meter_collection)
    create_self_consumption_data(pv_meter_map, meter_collection)
  end

  def days_pv(date, mpan)
    capacity = degraded_kwp(date)
    pv_yield = @synthetic_sheffield_solar_pv_yields[date]
    scaled_pv_kwh_x48 = AMRData.one_day_zero_kwh_x48
    scaled_pv_kwh_x48 = AMRData.fast_multiply_x48_x_scalar(pv_yield, capacity / 2.0) unless capacity.nil? || pv_yield.nil?
    OneDayAMRReading.new(mpan, date, 'SOLR', nil, DateTime.now, scaled_pv_kwh_x48)
  end

  private

  def create_generation_data(pv_meter_map, create_zero_if_no_config)
    pv_meter_map[:generation] = create_generation_meter_from_map(pv_meter_map) if pv_meter_map[:generation].nil?

    create_generation_amr_data(
      pv_meter_map[:mains_consume].amr_data,
      pv_meter_map[:generation].amr_data,
      pv_meter_map[:mains_consume].mpan_mprn,
      create_zero_if_no_config
      )
  end

  def create_export_data(pv_meter_map, meter_collection)
    pv_meter_map[:export] = create_export_meter_from_map(pv_meter_map) if pv_meter_map[:export].nil?

    calculate_export_data(
      pv_meter_map[:mains_consume].amr_data,
      pv_meter_map[:generation].amr_data,
      pv_meter_map[:export].amr_data,
      meter_collection,
      pv_meter_map[:mains_consume].mpan_mprn
      )
  end

  def create_self_consumption_data(pv_meter_map, meter_collection)
    pv_meter_map[:self_consume] = create_self_consumption_meter_from_map(pv_meter_map) if pv_meter_map[:self_consume].nil?

    calculate_self_consumption_data(
      pv_meter_map[:mains_consume].amr_data,
      pv_meter_map[:generation].amr_data,
      pv_meter_map[:export].amr_data,
      pv_meter_map[:self_consume].amr_data,
      meter_collection,
      pv_meter_map[:mains_consume].mpan_mprn
      )
  end

  def create_generation_amr_data(mains_amr_data, pv_amr_data, mpan, create_zero_if_no_config)
    mains_amr_data.date_range.each do |date|
      if !degraded_kwp(date, :override_generation).nil? # set only where config says so
        pv = days_pv(date, mpan)
        pv_amr_data.add(date, pv)
      elsif create_zero_if_no_config
         # pad out generation data to that of mains electric meter
         # so downstream analysis doesn't need to continually test
         # for its existence
        pv_amr_data.add(date, OneDayAMRReading.zero_reading(mpan, date, 'SOL0'))
      end
    end
  end

  def calculate_export_data(mains_amr, pv_amr, export_amr, meter_collection, mpan)
    mains_amr.date_range.each do |date|
      if !degraded_kwp(date, :override_export).nil? # set only where config says so
        export_x48 = calculate_days_exported_days_data(date, meter_collection, mains_amr, pv_amr)
        export_amr.add(date, one_day_reading(mpan, date, 'SOLE', export_x48)) unless export_x48.nil?
      end
    end
  end

  def calculate_days_exported_days_data(date, meter_collection, mains_amr_data, pv_amr_data)
    return nil if degraded_kwp(date, :override_export).nil?

    export_x48    = AMRData.one_day_zero_kwh_x48
    pv_output_x48 = pv_amr_data.one_days_data_x48(date)
    baseload_kw   = yesterday_baseload_kw(date, mains_amr_data)
    unoccupied    = unoccupied?(meter_collection, date)

    (0..47).each do |hh_i|
      if unoccupied && mains_amr_data.kwh(date, hh_i) <= 0.0
        # if unoccupied then assume export is excess of generation over baseload
        export_x48[hh_i] = -1.0 * (pv_output_x48[hh_i] - (baseload_kw / 2.0))
      end
    end

    export_x48
  end

  def calculate_self_consumption_data(mains_amr, pv_amr, export_amr, self_consumption_amr, meter_collection, mpan)
    mains_amr.date_range.each do |date|
      if !degraded_kwp(date, :override_self_consume).nil? # set only where config says so
        self_consume_x48 = calculate_days_self_consumption_days_data(date, meter_collection, mains_amr, pv_amr)
        unless self_consume_x48.nil?
          exported_x48 = export_amr.one_days_data_x48(date)

          exported_x48, self_consume_x48 = normalise_pv(exported_x48, self_consume_x48)

          export_amr.add(date, one_day_reading(mpan, date, 'SOLO', exported_x48))
          self_consumption_amr.add(date, one_day_reading(mpan, date, 'SOLE', self_consume_x48))
        end
      end
    end
  end

  def calculate_days_self_consumption_days_data(date, meter_collection, mains_amr_data, pv_amr_data)
    return nil if degraded_kwp(date, :override_export).nil?

    self_x48      = AMRData.one_day_zero_kwh_x48
    pv_output_x48 = pv_amr_data.one_days_data_x48(date)
    baseload_kw   = yesterday_baseload_kw(date, mains_amr_data)
    unoccupied    = unoccupied?(meter_collection, date)

    (0..47).each do |hh_i|
      if unoccupied && mains_amr_data.kwh(date, hh_i) <= 0.0
        # if unoccupied and zero then assume consuming baseload
        self_x48[hh_i] = baseload_kw / 2.0
      else
        # else all the pv output is being consumed
        self_x48[hh_i] = pv_output_x48[hh_i]
      end
    end

    self_x48
  end

  def create_generation_meter_from_map(pv_meter_map)
    date_range, meter_to_clone, meter_collection = meter_creation_data(pv_meter_map)
    create_generation_meter(date_range, meter_to_clone, meter_collection)
  end

  def create_generation_meter(date_range, meter_to_clone, meter_collection)
    create_meter(
      meter_to_clone,
      :solar_pv,
      :solar_pv,
      meter_collection,
      SolarPVPanels::SOLAR_PV_PRODUCTION_METER_NAME,
      'SOLR'
    )
  end

  def create_export_meter_from_map(pv_meter_map)
    date_range, meter_to_clone, meter_collection = meter_creation_data(pv_meter_map)
    create_export_meter(date_range, meter_to_clone, meter_collection)
  end

  def create_export_meter(date_range, meter_to_clone, meter_collection)
    create_meter(
      meter_to_clone,
      :exported_solar_pv,
      :solar_pv_exported_sub_meter,
      meter_collection,
      SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
      'SOLE'
    )
  end

  def create_self_consumption_meter_from_map(pv_meter_map)
    date_range, meter_to_clone, meter_collection = meter_creation_data(pv_meter_map)
    create_self_consumption_meter(date_range, meter_to_clone, meter_collection)
  end

  def create_self_consumption_meter(date_range, meter_to_clone, meter_collection)
    create_meter(
      meter_to_clone,
      :solar_pv,
      :solar_pv_consumed_sub_meter,
      meter_collection,
      SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME,
      'SOLO'
    )
  end

  def create_meter(meter_to_clone, meter_type, pseudo_meter_type, meter_collection, meter_name, reading_type)
    date_range = meter_to_clone.amr_data.date_range
    amr_data = AMRData.create_empty_dataset(meter_type, date_range.first, date_range.last, reading_type)

    Dashboard::Meter.new(
      meter_collection: meter_to_clone.meter_collection,
      amr_data: amr_data,
      type: meter_type,
      identifier: Dashboard::Meter.synthetic_combined_meter_mpan_mprn_from_urn(meter_collection.urn, meter_type),
      name: meter_name,
      floor_area: meter_to_clone.floor_area,
      number_of_pupils: meter_to_clone.number_of_pupils,
      solar_pv_installation: meter_to_clone.solar_pv_setup,
      storage_heater_config: meter_to_clone.storage_heater_setup,
      meter_attributes: meter_to_clone.meter_attributes.merge(meter_to_clone.meter_collection.pseudo_meter_attributes(pseudo_meter_type))
    )
  end

  def meter_creation_data(pv_meter_map)
    [
      pv_meter_map[:mains_consume].amr_data.date_range,
      pv_meter_map[:mains_consume],
      pv_meter_map[:mains_consume].meter_collection
    ]
  end

  def degraded_kwp(date, override_key = :override_generation)
    @solar_pv_panel_config.degraded_kwp(date, override_key)
  end

  def one_day_reading(mpan, date, type, data_x48 = Array.new(48, 0.0))
    OneDayAMRReading.new(mpan, date, type, nil, DateTime.now, data_x48)
  end

  # to avoid persistent bias in output rescale pv_consumed_onsite_kwh_x48 if
  # the baseload minus the predicted pv output doesn't result in an export
  # and the mains consumption is zero or near zero, i.e. mains consumption is zero
  # but there isn't enough predicted pv to result in an export
  def normalise_pv(exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48)
    positive_export_kwh = exported_pv_kwh_x48.map { |kwh| kwh > 0.0 ? kwh : 0.0 }.sum # map then sum to avoid StatSample sum bug
    negative_only_exported_kwh_x48 = exported_pv_kwh_x48.map { |kwh| kwh > 0.0 ? 0.0 : kwh }
    days_pv_consumed_onsite_kwh = pv_consumed_onsite_kwh_x48.sum
    scale_factor = days_pv_consumed_onsite_kwh == 0 ? 1.0 : 1.0 + (positive_export_kwh / days_pv_consumed_onsite_kwh)
    scaled_onsite_kwh_x48 = pv_consumed_onsite_kwh_x48.map { |kwh| kwh * scale_factor }
    [negative_only_exported_kwh_x48, scaled_onsite_kwh_x48]
  end

  def unoccupied?(meter_collection, date)
    DateTimeHelper.weekend?(date) || meter_collection.holidays.holiday?(date)
  end

  def yesterday_baseload_kw(date, electricity_amr)
    yesterday_date = date == electricity_amr.start_date ? electricity_amr.start_date : (date - 1)
    electricity_amr.overnight_baseload_kw(yesterday_date)
  end
end
