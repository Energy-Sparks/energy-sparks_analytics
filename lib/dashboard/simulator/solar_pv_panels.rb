# Collection of solar pv panel related functions
class SolarPVPanels
  include Logging

  def initialize(solar_pv_attributes)
    @solar_pv_panel_config = SolarPVPanelConfiguration.new(solar_pv_attributes)
  end

  def kwp(date)
    @solar_pv_panel_config.kwp(date)
  end

  def degraded_kwp(date)
    kwp(date)
  end

  def create_solar_pv_amr_data(electricity_amr, meter_collection, mpan_solar_pv)
    solar_amr = AMRData.new(:solar_pv)
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

  class SolarPVPanelConfiguration
    MIN_DEFAULT_START_DATE = Date.new(2011, 1, 1)
    MAX_DEFAULT_END_DATE   = Date.new(2050, 1, 1)

    def initialize(solar_pv_attributes)
      @config_by_date_range = {} # date_range = config
      parse_solar_pv_attributes(solar_pv_attributes)
    end

    def kwp(date)
      capacity = @config_by_date_range.select{ |dates, _config| dates === date }.map { |_date_range, panel_set| panel_set[:kwp] }
      capacity.empty? ? nil : capacity.sum # explicilty signal abscence of panels on date with nil
    end

    # ultimately need to deal with panel degredation TODO(PH,21Mar2019)
    def degraded_kwp(date)
      kwp(date)
    end

    private def parse_solar_pv_attributes(solar_pv_attributes)
      # puts "solar pv config #{solar_pv_attributes}"
      if solar_pv_attributes.is_a?(Array)
        solar_pv_attributes.each do |period_config|
          @config_by_date_range.merge!(parse_solar_pv_attributes_for_period(period_config))
        end
      elsif solar_pv_attributes.is_a?(Hash)
        @config_by_date_range.merge!(parse_solar_pv_attributes_for_period(solar_pv_attributes))
      else
        raise EnergySparksMeterSpecification.new('Unexpected meter attributes for solar pv, expecting array of hashes or 1 hash')
      end
    end

    private def parse_solar_pv_attributes_for_period(period_config)
      start_date = (!period_config.nil? && period_config.key?(:start_date)) ? period_config[:start_date] : MIN_DEFAULT_START_DATE
      end_date   = (!period_config.nil? && period_config.key?(:end_date) )  ? period_config[:end_date]   : MAX_DEFAULT_END_DATE

      # will need a case statement at some point to parse this properly? TODO(PH,21Mar2019)
      config = period_config.select{ |param, _value| %i[kwp orientation tilt shading fit_£_per_kwh].include?(param) }

      { start_date..end_date => config }
    end
  end
end
