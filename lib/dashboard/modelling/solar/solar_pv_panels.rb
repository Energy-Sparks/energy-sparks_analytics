# creates new solar pv panel data synthetically from Sheffield University sourced data
# and can also use this to override real solar pv metering when it goes wrong via meter attributes
# uses the SolarPV, SolarPVOverrides, SolarPVMeterMapping meter attributes for configuration
class SolarPVPanels
  include Logging
  attr_reader :meter_attributes_config, :real_production_data

  MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV = 'Electricity consumed including onsite solar pv consumption'.freeze
  SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME = 'Electricity consumed from solar pv'.freeze
  SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME = 'Exported solar electricity (not consumed onsite)'.freeze
  ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME = 'Electricity consumed from mains'.freeze
  SOLAR_PV_PRODUCTION_METER_NAME = 'Solar PV Production'

  SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME_I18N_KEY = 'electricity_consumed_from_solar_pv'.freeze
  SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME_I18N_KEY = 'exported_solar_electricity'.freeze
  ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME_I18N_KEY = 'electricity_consumed_from_mains'.freeze

  SUBMETER_TYPES = [
    ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME,
    SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME,
    SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
  ]

  def initialize(meter_attributes_config, synthetic_sheffield_solar_pv_yields)
    @solar_pv_panel_config = SolarPVPanelConfiguration.new(meter_attributes_config) unless meter_attributes_config.nil?
    @synthetic_sheffield_solar_pv_yields = synthetic_sheffield_solar_pv_yields
    @debug_date_range = nil # Date.new(2021, 6, 18)..Date.new(2021, 6, 19) # Date.new(2021, 6, 1)..Date.new(2021, 6, 7) || nil
    @real_production_data = false
  end

  def first_installation_date
    @solar_pv_panel_config.first_installation_date
  end

  def process(pv_meter_map, meter_collection)
    print_detailed_results(pv_meter_map, 'Before solar pv calculation:')
    create_generation_data(pv_meter_map, false)
    create_export_meter_if_missing(pv_meter_map)
    create_or_override_export_data(pv_meter_map, meter_collection)
    create_self_consumption_meter_if_missing(pv_meter_map)
    create_self_consumption_data(pv_meter_map, meter_collection)
    print_detailed_results(pv_meter_map, 'After solar pv calculation')
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

  def create_export_meter_if_missing(pv_meter_map)
    pv_meter_map[:export] = create_export_meter_from_map(pv_meter_map) if pv_meter_map[:export].nil?
  end

  def create_or_override_export_data(pv_meter_map, meter_collection)
    override_export_data_detail(
      pv_meter_map[:mains_consume].amr_data,
      pv_meter_map[:generation].amr_data,
      pv_meter_map[:export].amr_data,
      meter_collection,
      pv_meter_map[:mains_consume].mpan_mprn
      )
  end

  def create_self_consumption_meter_if_missing(pv_meter_map)
    pv_meter_map[:self_consume] = create_self_consumption_meter_from_map(pv_meter_map) if pv_meter_map[:self_consume].nil?
  end

  def create_self_consumption_data(pv_meter_map, meter_collection)
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
      if synthetic_data?(date, :override_generation) # set only where config says so, either override or straight Sheffield synthetic case
        pv = days_pv(date, mpan)
        pv_amr_data.add(date, pv)
        compact_print_day('override generation', date, pv.kwh_data_x48)
      elsif create_zero_if_no_config
         # pad out generation data to that of mains electric meter
         # so downstream analysis doesn't need to continually test
         # for its existence
        pv_amr_data.add(date, OneDayAMRReading.zero_reading(mpan, date, 'SOL0'))
        compact_print_day('override generation zero', date, negative_only_exported_kwh_x48)
      end
    end
  end

  def override_export_data_detail(mains_amr, pv_amr, export_amr, meter_collection, mpan)
    mains_amr.date_range.each do |date|
      if synthetic_data?(date, :override_export) # set only where config says so
        export_x48 = calculate_days_exported_days_data(date, meter_collection, mains_amr, pv_amr)
        export_amr.add(date, one_day_reading(mpan, date, 'SOLE', export_x48)) unless export_x48.nil?
      end
    end
  end

  def maximum_export_kw(date)
    return 0.0 if real_production_data
    config = @solar_pv_panel_config.config_by_date_range.select { |date_range, config| date.between?(date_range.first, date_range.last) }
    return 0.0 if config.empty?

    config.values.first[:maximum_export_level_kw] || 0.0
  end

  def calculate_days_exported_days_data(date, meter_collection, mains_amr_data, pv_amr_data)
    return nil unless synthetic_data?(date, :override_export)

    export_x48    = AMRData.one_day_zero_kwh_x48
    pv_output_x48 = pv_amr_data.one_days_data_x48(date)
    baseload_kw   = yesterday_baseload_kw(date, mains_amr_data)
    unoccupied    = unoccupied?(meter_collection, date)

    max_hh_export_kwh = maximum_export_kw(date) / 2.0

    (0..47).each do |hh_i|
      # arguably this could be improved by changing <= 0.0 to something a little less
      # strict in the sense the half hour could be part cloudy, part sunny so
      # there will be some export and some mains consumption
      # PH: 19Aug2022: comment above proved correct, non-zero override now supported
      if unoccupied && mains_amr_data.kwh(date, hh_i) <= max_hh_export_kwh
        # if unoccupied then assume export is excess of generation over baseload
        export_x48[hh_i] = -1.0 * (pv_output_x48[hh_i] - (baseload_kw / 2.0))
      end
    end

    compact_print_day('export', date, export_x48)

    export_x48
  end

  def calculate_self_consumption_data(mains_amr, pv_amr, export_amr, self_consumption_amr, meter_collection, mpan)
    mains_amr.date_range.each do |date|
      if synthetic_data?(date, :override_self_consume) # set only where config says so
        self_consume_x48 = calculate_days_self_consumption_days_data(date, meter_collection, mains_amr, pv_amr)
        unless self_consume_x48.nil?
          exported_x48 = export_amr.one_days_data_x48(date)

          exported_x48, self_consume_x48 = normalise_pv(date, exported_x48, self_consume_x48)

          export_amr.add(date, one_day_reading(mpan, date, 'SOLO', exported_x48))
          self_consumption_amr.add(date, one_day_reading(mpan, date, 'SOLE', self_consume_x48))
        end
      end
    end
  end

  def calculate_days_self_consumption_days_data(date, meter_collection, mains_amr_data, pv_amr_data)
    return nil unless synthetic_data?(date, :override_self_consume)

    self_x48      = AMRData.one_day_zero_kwh_x48
    pv_output_x48 = pv_amr_data.one_days_data_x48(date)
    baseload_kw   = yesterday_baseload_kw(date, mains_amr_data)
    unoccupied    = unoccupied?(meter_collection, date)

    max_hh_export_kwh = maximum_export_kw(date) / 2.0

    (0..47).each do |hh_i|
      if unoccupied && mains_amr_data.kwh(date, hh_i) <= max_hh_export_kwh
        # if unoccupied and zero then assume consuming baseload
        self_x48[hh_i] = baseload_kw / 2.0
      else
        # else all the pv output is being consumed
        self_x48[hh_i] = pv_output_x48[hh_i]
      end
    end

    compact_print_day('self consumption', date, self_x48)

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
  def normalise_pv(date, exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48)
    positive_export_kwh = exported_pv_kwh_x48.map { |kwh| kwh > 0.0 ? kwh : 0.0 }.sum # map then sum to avoid StatSample sum bug
    negative_only_exported_kwh_x48 = exported_pv_kwh_x48.map { |kwh| kwh > 0.0 ? 0.0 : kwh }
    days_pv_consumed_onsite_kwh = pv_consumed_onsite_kwh_x48.sum
    scale_factor = days_pv_consumed_onsite_kwh == 0 ? 1.0 : 1.0 + (positive_export_kwh / days_pv_consumed_onsite_kwh)
    scaled_onsite_kwh_x48 = pv_consumed_onsite_kwh_x48.map { |kwh| kwh * scale_factor }
            
    compact_print_day('normalised export', date, negative_only_exported_kwh_x48)
    compact_print_day('scaled onsite',     date, scaled_onsite_kwh_x48)

    [negative_only_exported_kwh_x48, scaled_onsite_kwh_x48]
  end

  def unoccupied?(meter_collection, date)
    DateTimeHelper.weekend?(date) || meter_collection.holidays.holiday?(date)
  end

  def yesterday_baseload_kw(date, electricity_amr)
    yesterday_date = date == electricity_amr.start_date ? electricity_amr.start_date : (date - 1)
    electricity_amr.overnight_baseload_kw(yesterday_date)
  end

  def synthetic_data?(date, type)
    !@solar_pv_panel_config.nil? && !degraded_kwp(date, type).nil?
  end

  def debug_date?(date)
    return false if @debug_date_range.nil?

    date.between?(@debug_date_range.first, @debug_date_range.last)
  end

  def compact_print_day(type, date, kwh_x48)
    return unless debug_date?(date)

    puts "Calculated #{type} for #{date.strftime('%a %d %b %Y')} total = #{kwh_x48.sum.round(1)}"

    max_val = [kwh_x48.min.magnitude, kwh_x48.max.magnitude].max
    digits = max_val > 0.0 ? (Math.log10(max_val) + 2) : 2

    row_length = 48
    format = '%*.0f ' * row_length
    format_width = Array.new(row_length, digits.to_i)
    kwh_x48.each_slice(row_length) do |kwh_x8|
      puts format % format_width.zip(kwh_x8).flatten
    end
  end

  def print_detailed_results(pv_meter_map, when_message)
    return if @debug_date_range.nil?

    puts '-' * 60
    puts when_message

    @debug_date_range.each do |date|
      pv_meter_map.each do |type, meter|
        next if meter.nil?

        compact_print_day(type, date, meter.amr_data.days_kwh_x48(date))
      end
    end

    puts '-' * 60
  end
end

# called where metered generation meter but no export or self consumption
class SolarPVPanelsMeteredProduction < SolarPVPanels
  def initialize
    super(nil, nil)
    @real_production_data = true
  end

  private

  def create_generation_amr_data(mains_amr_data, pv_amr_data, mpan, create_zero_if_no_config)
    mains_amr_data.date_range.each do |date|
      unless pv_amr_data.date_exists?(date)
         # pad out generation data to that of mains electric meter
         # so downstream analysis doesn't need to continually test
         # for its existence
        pv_amr_data.add(date, OneDayAMRReading.zero_reading(mpan, date, 'SOL0'))
      end
    end
  end

  def synthetic_data?(_date, type)
    true
  end
end
