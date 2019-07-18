# Collection of solar pv panel related functions
class SolarPVPanels
  include Logging

  MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV = 'Electricity consumed including onsite solar pv consumption'.freeze
  SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME = 'Electricity consumed from solar pv'.freeze
  SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME = 'Exported solar electricity (not consumed onsite)'.freeze
  ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME = 'Electricity consumed from mains'.freeze

  def initialize(meter_attributes_config)
    @solar_pv_panel_config = SolarPVPanelConfiguration.new(meter_attributes_config)
  end

  def degraded_kwp(date)
    @solar_pv_panel_config.degraded_kwp(date)
  end

  # takes original electricity mains consumption meter data, and creates
  # 1. solar pv output
  # 2. exported solar pv (based on excess over baseload; weekends and holidays only, initially)
  # 3. pv consumed onsite
  # 4. electricity consumed onsite (original electricity meter, plus pv consumed onsite)
  # TODO(PH. 15Jul2019) - can't cope with school day where solar PV output > consumption
  #                     - would require fitting of usage patterns on days with no export
  def create_solar_pv_data(electricity_amr, meter_collection, mpan_solar_pv)
    solar_pv_output_amr = AMRData.new(:solar_pv)
    exported_solar_pv_amr = AMRData.new(:solar_pv)
    solar_pv_consumed_onsite_amr = AMRData.new(:electricity)
    electricity_consumed_onsite_amr = AMRData.new(:electricity)

    (electricity_amr.start_date..electricity_amr.end_date).each do |date|
      capacity = degraded_kwp(date)
      pv_yield_x48 = meter_collection.solar_pv[date]

      pv_consumed_onsite_kwh_x48 = AMRData.one_day_zero_kwh_x48
      solar_pv_panel_output_kwh_x48 = AMRData.one_day_zero_kwh_x48
      exported_pv_kwh_x48 = AMRData.one_day_zero_kwh_x48

      if !capacity.nil? && !pv_yield_x48.nil?
        exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48, solar_pv_panel_output_kwh_x48 =
          days_exported_and_onsite_consumed_pv(meter_collection, date, capacity, electricity_amr, pv_yield_x48, pv_consumed_onsite_kwh_x48, solar_pv_panel_output_kwh_x48)
      end

      electricity_consumed_onsite_x48 = AMRData.one_day_zero_kwh_x48
      (0..47).each do |halfhour_index|
        electricity_consumed_onsite_x48[halfhour_index] = electricity_amr.kwh(date, halfhour_index) + pv_consumed_onsite_kwh_x48[halfhour_index]
      end

      solar_pv_output_amr.add(date, one_day_reading(mpan_solar_pv, date, 'SOLR', solar_pv_panel_output_kwh_x48))
      exported_solar_pv_amr.add(date, one_day_reading(mpan_solar_pv, date, 'SOLE', exported_pv_kwh_x48))
      solar_pv_consumed_onsite_amr.add(date, one_day_reading(mpan_solar_pv, date, 'SOLO', pv_consumed_onsite_kwh_x48))
      electricity_consumed_onsite_amr.add(date, one_day_reading(mpan_solar_pv, date, 'SOLX', electricity_consumed_onsite_x48))
    end

    log_disaggregation_results(electricity_amr, electricity_consumed_onsite_amr, solar_pv_consumed_onsite_amr, exported_solar_pv_amr, solar_pv_output_amr)

    {
      electricity_consumed_onsite:  electricity_consumed_onsite_amr,
      solar_consumed_onsite:        solar_pv_consumed_onsite_amr,
      exported:                     exported_solar_pv_amr,
      solar_pv_output:              solar_pv_output_amr
    }
  end

  private def log_disaggregation_results(electricity_amr, electricity_consumed_onsite_amr, solar_pv_consumed_onsite_amr, exported_solar_pv_amr, solar_pv_output_amr)
    logger.info "Disaggregated electricity meter with #{electricity_amr.total.round(0)} kWh data"
    logger.info 'Created:'
    logger.info "    #{electricity_consumed_onsite_amr.total.round(0)} kWh consumed onsite"
    logger.info "    #{solar_pv_consumed_onsite_amr.total.round(0)} kWh solar consumed onsite"
    logger.info "    #{exported_solar_pv_amr.total.round(0)} kWh solar exported onsite"
    logger.info "    #{solar_pv_output_amr.total.round(0)} kWh total panel output"
  end

  private def one_day_reading(mpan, date, type, data_x48)
    OneDayAMRReading.new(mpan, date, type, nil, DateTime.now, data_x48)
  end

  private def days_exported_and_onsite_consumed_pv(meter_collection, date, capacity, electricity_amr, pv_yield_x48, pv_consumed_onsite_kwh_x48, solar_pv_panel_output_kwh_x48)
    baseload_kw = yesterday_baseload_kw(date, electricity_amr)
    unoccupied = unoccupied?(meter_collection, date)
    exported_pv_kwh_x48 = AMRData.one_day_zero_kwh_x48

    pv_yield_x48.each_with_index do |yield_kwh_per_kwp, halfhour_index|
      metered_electricity_consumption_kwh = electricity_amr.kwh(date, halfhour_index)
      solar_pv_panel_output_kwh_x48[halfhour_index] = yield_kwh_per_kwp * capacity / 2.0
      if unoccupied && metered_electricity_consumption_kwh <= 0.0 # 0.5 kWh nominal noise
        pv_consumed_onsite_kwh_x48[halfhour_index] = baseload_kw / 2.0
        exported_pv_kwh_x48[halfhour_index] = -1.0 * (solar_pv_panel_output_kwh_x48[halfhour_index] - pv_consumed_onsite_kwh_x48[halfhour_index])
      else
        pv_consumed_onsite_kwh_x48[halfhour_index] = solar_pv_panel_output_kwh_x48[halfhour_index]
      end
    end
    exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48 = normalise_pv(exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48)
    [exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48, solar_pv_panel_output_kwh_x48]
  end

  # to avoid persistent bias in output rescale pv_consumed_onsite_kwh_x48 if
  # the baseload minus the predicted pv output is doesn't result in an export
  # and the mains consumption is zero or near zero, i.e. mains consumption is zero
  # but there isn't enough predicted pv to result in an export
  private def normalise_pv(exported_pv_kwh_x48, pv_consumed_onsite_kwh_x48)
    positive_export_kwh = exported_pv_kwh_x48.sum { |kwh| kwh > 0.0 ? kwh : 0.0 }
    negative_only_exported_kwh_x48 = exported_pv_kwh_x48.map { |kwh| kwh > 0.0 ? 0.0 : kwh }
    scale_factor = 1.0 + (positive_export_kwh / pv_consumed_onsite_kwh_x48.sum)
    scaled_onsite_kwh_x48 = pv_consumed_onsite_kwh_x48.map { |kwh| kwh * scale_factor }
    [negative_only_exported_kwh_x48, scaled_onsite_kwh_x48]
  end

  private def unoccupied?(meter_collection, date)
    DateTimeHelper.weekend?(date) || meter_collection.holidays.holiday?(date)
  end

  private def yesterday_baseload_kw(date, electricity_amr)
    yesterday_date = date == electricity_amr.start_date ? electricity_amr.start_date : (date - 1)
    yesterday_baseload_kw = electricity_amr.overnight_baseload_kw(yesterday_date)
  end

  def create_solar_pv_amr_data_deprecated(electricity_amr, meter_collection, mpan_solar_pv)
    solar_amr = AMRData.new(:solar_pv)
    puts "Doing #{electricity_amr.start_date} to #{electricity_amr.end_date}"
    (electricity_amr.start_date..electricity_amr.end_date).each do |date|
      capacity = degraded_kwp(date)
      pv_yield = meter_collection.solar_pv[date]
      scaled_pv_kwh_x48 = Array.new(48, 0.0)
      if !capacity.nil? && !pv_yield.nil?
        producer = 1.0 # positive kWh despite producer rather than consumer
        scaled_pv_kwh_x48 = pv_yield.map { |i| i * capacity * producer / 2.0 }
      end
      solar_amr.add(date, OneDayAMRReading.new(mpan_solar_pv, date, 'SOLR', nil, DateTime.now, scaled_pv_kwh_x48))
    end
    logger.info "Created new solar pv meter with #{solar_amr.length} days of data #{solar_amr.total} kWh total"
    solar_amr
  end

  def disaggregate_amr_data(amr_data, mpan_mprn)
    storage_heater_amr_data = AMRData.new(:storage_heater)
    electricity_only_amr_data = AMRData.new(:electricity)
    mpan_mprn_storage_heater = mpan_mprn # TODO PH 20Mar2019 - create unique mpan for synthetic meter
    mpan_mprn_electric_only  = mpan_mprn # TODO PH 20Mar2019 - create unique mpan for synthetic meter

    (amr_data.start_date..amr_data.end_date).each do |date|
      if @storage_heater_config.in_operation?(date)
        storage_heater_kwh = Array.new(48, 0.0)
        electric_only_kwh = Array.new(48, 0.0)
        baseload_sample_date = date > amr_data.start_date ? date - 1 : date
        baseload_kwh = amr_data.statistical_baseload_kw(baseload_sample_date) / 2.0
        (0..47).each do |halfhour_index|
          kwh = amr_data.kwh(date, halfhour_index)
          if storage_heater_on?(amr_data, date, halfhour_index, baseload_kwh)
            storage_heater_kwh[halfhour_index] = [kwh - baseload_kwh, 0.0].max
            electric_only_kwh[halfhour_index] = [kwh, baseload_kwh].min
          else
            electric_only_kwh[halfhour_index] = kwh
          end
        end
        storage_heater_amr_data.add(  date, OneDayAMRReading.new(mpan_mprn_storage_heater, date, 'STOR', nil, DateTime.now, storage_heater_kwh))
        electricity_only_amr_data.add(date, OneDayAMRReading.new(mpan_mprn_electric_only,  date, 'STEX', nil, DateTime.now, electric_only_kwh))
      else # non storage heater day, just copy days kwh data
        electricity_only_amr_data.add(date, amr_data.clone_one_days_data(date))
      end
    end
    logger.info "Disaggregated storage heater #{amr_data.total.round(0)} kWh => sh #{storage_heater_amr_data.total.round(0)} e-sh #{electricity_only_amr_data.total.round(0)}"
    puts "Disaggregated storage heater #{amr_data.total.round(0)} kWh => sh #{storage_heater_amr_data.total.round(0)} e-sh #{electricity_only_amr_data.total.round(0)}"

    [electricity_only_amr_data, storage_heater_amr_data]
  end

  class SolarPVPanelConfiguration
    MIN_DEFAULT_START_DATE = Date.new(2011, 1, 1)
    MAX_DEFAULT_END_DATE   = Date.new(2050, 1, 1)

    def initialize(meter_attributes_config)
      @config_by_date_range = {} # date_range = config
      parse_meter_attributes_configuration(meter_attributes_config)
    end

    def degraded_kwp(date)
      degraded_capacity_on_date_kw(date)
      # capacity = @config_by_date_range.select{ |dates, _config| date >= dates.first && date <= dates.last }.map { |_date_range, panel_set| panel_set[:kwp] }
      # capacity.empty? ? nil : capacity.sum # explicitly signal abscence of panels on date with nil
    end

    private def degraded_capacity_on_date_kw(date)
      degraded_capacity = 0.0
      panel_set_capacities = @config_by_date_range.select{ |dates, _config| date >= dates.first && date <= dates.last }
      return nil if panel_set_capacities.empty?

      panel_set_capacities.each do |date_range, panel_set_config|
        degraded_capacity += panel_set_config[:kwp] * degredation(date_range.first, date)
      end
      degraded_capacity
    end

    def degredation(from_date, to_date)
      years = (to_date - from_date) / 365.0
      # allow 0.5% degredation per year
      (1.0 - 0.005)**years
    end

    private def parse_meter_attributes_configuration(meter_attributes_config)
  
      if meter_attributes_config.is_a?(Array)
        meter_attributes_config.each do |period_config|
          @config_by_date_range.merge!(parse_meter_attributes_configuration_for_period(period_config))
        end
      elsif meter_attributes_config.is_a?(Hash)
        @config_by_date_range.merge!(parse_meter_attributes_configuration_for_period(meter_attributes_config))
      else
        raise EnergySparksMeterSpecification.new('Unexpected meter attributes for solar pv, expecting array of hashes or 1 hash')
      end
    end

    private def parse_meter_attributes_configuration_for_period(period_config)
      start_date = (!period_config.nil? && period_config.key?(:start_date)) ? period_config[:start_date] : MIN_DEFAULT_START_DATE
      end_date   = (!period_config.nil? && period_config.key?(:end_date) )  ? period_config[:end_date]   : MAX_DEFAULT_END_DATE

      # will need a case statement at some point to parse this properly? TODO(PH,21Mar2019)
      config = period_config.select{ |param, _value| %i[kwp orientation tilt shading fit_£_per_kwh].include?(param) }

      { start_date..end_date => config }
    end
  end
end
