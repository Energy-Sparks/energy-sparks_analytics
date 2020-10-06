module Dashboard
  # meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
  class Meter
    include Logging

    # Extra fields - potentially a concern or mix-in
    attr_reader :fuel_type, :meter_collection, :meter_attributes
    attr_reader :solar_pv_setup, :storage_heater_setup, :sub_meters
    attr_reader :meter_correction_rules, :model_cache
    attr_accessor :amr_data,  :floor_area, :number_of_pupils

    # Energy Sparks activerecord fields:
    attr_reader :active, :created_at, :meter_no, :meter_type, :school, :updated_at, :mpan_mprn
    attr_accessor :id, :name, :external_meter_id
    # enum meter_type: [:electricity, :gas]

    def initialize(meter_collection:, amr_data:, type:, identifier:, name:,
                    floor_area: nil, number_of_pupils: nil,
                    solar_pv_installation: nil,
                    storage_heater_config: nil, # now redundant PH 20Mar2019
                    external_meter_id: nil,
                    meter_attributes: {})
      @amr_data = amr_data
      @meter_collection = meter_collection
      @meter_type = type # think Energy Sparks variable naming is a minomer (PH,31May2018)
      check_fuel_type(fuel_type)
      @fuel_type = type
      set_mpan_mprn_id(identifier)
      @name = name
      @floor_area = floor_area
      @number_of_pupils = number_of_pupils
      @solar_pv_installation = solar_pv_installation
      @meter_correction_rules = []
      @sub_meters = []
      @external_meter_id = external_meter_id
      set_meter_attributes(meter_attributes)
      @model_cache = AnalyseHeatingAndHotWater::ModelCache.new(self)
      logger.info "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{number_of_pupils}"
    end

    def set_meter_attributes(meter_attributes)
      @meter_attributes = meter_attributes
      process_meter_attributes
    end

    def amr_data=(amr_data)
      @amr_data = amr_data
    end

    def set_mpan_mprn_id(identifier)
      @id = identifier
      @mpan_mprn = identifier.to_i
    end

    private def process_meter_attributes
      @storage_heater_setup = StorageHeater.new(attributes(:storage_heaters)) if @meter_attributes.key?(:storage_heaters)
      @solar_pv_setup = SolarPVPanels.new(attributes(:solar_pv)) if @meter_attributes.key?(:solar_pv)
      @low_carbon_hub_solar_pv = true if @meter_attributes.key?(:low_carbon_hub_meter_id)
      @solar_for_schools_solar_pv = true if @meter_attributes.key?(:solar_for_schools_meter_id)
    end

    private def check_fuel_type(fuel_type)
      raise EnergySparksUnexpectedStateException.new("Unexpected fuel type #{fuel_type}") if [:electricity, :gas].include?(fuel_type)
    end

    def to_s
      @mpan_mprn.to_s + ':' + @fuel_type.to_s + 'x' + (@amr_data.nil? ? '0' : @amr_data.length.to_s)
    end

    def attributes(type)
      @meter_attributes[type]
    end

    def all_attributes
      @meter_attributes
    end

    def storage_heater?
      !@storage_heater_setup.nil? || @fuel_type == :storage_heater # TODO(PH, 14Sep2019) remove @sstorage_heater_setup test?
    end

    def solar_pv_panels?
      low_carbon_hub_solar_pv_panels? || sheffield_simulated_solar_pv_panels? || solar_for_schools_solar_pv_panels?
    end

    def sheffield_simulated_solar_pv_panels?
      !@solar_pv_setup.nil?
    end

    def real_solar_pv_metering_x3?
      low_carbon_hub_solar_pv_panels? || solar_for_schools_solar_pv_panels?
    end

    def low_carbon_hub_solar_pv_panels?
      !@low_carbon_hub_solar_pv.nil?
    end

    def solar_for_schools_solar_pv_panels?
      !@solar_for_schools_solar_pv.nil?
    end

    def non_heating_only?
      function_includes?(:hotwater_only, :kitchen_only)
    end

    def kitchen_only?
      # wouldn't expect weekend or holiday use
      function_includes?(:kitchen_only)
    end

    def hot_water_only?
      function_includes?(:hotwater_only)
    end

    def heating_only?
      function_includes?(:heating_only)
    end

    private def function_includes?(*function_list)
      function = attributes(:function)
      !function.nil? && !(function_list & function).empty?
    end

    def heating_model(period, model_type = :best)
      @model_cache.create_and_fit_model(model_type, period)
    end

    def meter_collection
      school || @meter_collection
    end

    def heat_meter?
      [:gas, :storage_heater, :aggregated_heat].include?(fuel_type)
    end

    def electricity_meter?
      [:electricity, :solar_pv, :aggregated_electricity].include?(fuel_type)
    end

    def set_meter_no(meter_no)
      @meter_no = meter_no
    end

    def insert_correction_rules_first(rules)
      @meter_correction_rules = rules + @meter_correction_rules
    end

    # Matches ES AR version
    def display_name
      name.present? ? "#{meter_no} (#{name})" : display_meter_number
    end

    def display_meter_number
      meter_no.present? ? meter_no : meter_type.to_s
    end

    def synthetic_mpan_mprn?
      mpan_mprn > 60000000000000 
    end

    def aggregate_meter?
      # TODO(PH, 14Sep2019) - Make 90000000000000 etc. masks constants
      90000000000000 & mpan_mprn > 0 || 80000000000000 & mpan_mprn > 0
    end

    def self.synthetic_combined_meter_mpan_mprn_from_urn(urn, fuel_type, group_number = 0)
      if fuel_type == :electricity || fuel_type == :aggregated_electricity
        90000000000000 + urn.to_i
      elsif fuel_type == :gas || fuel_type == :aggregated_heat
        80000000000000 + urn.to_i
      elsif fuel_type == :storage_heater # suspect as same number as solar_pv; TODO(PH, 14Sep2019)
        70000000000000 + urn.to_i
      elsif fuel_type == :solar_pv
        70000000000000 + urn.to_i + 1000000000000 * group_number
      elsif fuel_type == :exported_solar_pv
        60000000000000 + urn.to_i + 1000000000000 * group_number
      else
        raise EnergySparksUnexpectedStateException.new, "Unexpected fuel_type #{fuel_type}"
      end
    end

    def self.synthetic_mpan_mprn(mpan_mprn, type)
      mpan_mprn = mpan_mprn.to_i
      case type
      when :storage_heater_only
        70000000000000 + mpan_mprn
      when :electricity_minus_storage_heater
        75000000000000 + mpan_mprn
      else
        raise EnergySparksUnexpectedStateException.new("Unexpected type #{type} for modified mpan/mprn")
      end
    end
  end
end
