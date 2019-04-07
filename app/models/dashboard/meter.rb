module Dashboard
  # meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
  class Meter
    include Logging

    # Extra fields - potentially a concern or mix-in
    attr_reader :fuel_type, :meter_collection, :meter_attributes
    attr_reader :solar_pv_setup, :storage_heater_setup, :sub_meters
    attr_reader :model_cache, :economic_tariff
    attr_accessor :amr_data, :floor_area, :number_of_pupils

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
      @id = identifier
      @mpan_mprn = identifier.to_i
      @name = name
      @floor_area = floor_area
      @number_of_pupils = number_of_pupils
      @solar_pv_installation = solar_pv_installation
      @meter_correction_rules = []
      @sub_meters = []
      @external_meter_id = external_meter_id
      @meter_attributes = meter_attributes
      process_meter_attributes
      @model_cache = AnalyseHeatingAndHotWater::ModelCache.new(self)
      logger.info "Creating new meter: type #{type} id: #{identifier} name: #{name} floor area: #{floor_area} pupils: #{number_of_pupils}"
    end

    def amr_data=(amr_data)
      @amr_data = amr_data
      set_economic_amr_tariff
    end

    def set_economic_amr_tariff(default_energy_purchaser)
      @amr_data.set_economic_tariff(mpan_mprn, @fuel_type, default_energy_purchaser)
    end

    def set_accounting_amr_tariff(default_energy_purchaser)
      @amr_data.set_accounting_tariff(mpan_mprn, @fuel_type, default_energy_purchaser)
    end

    # set this here rather than lazy loading in AMRdata instance, so first access isn't slow
    def set_amr_data_carbon_intensity_deprecated
      @amr_data.set_carbon_emissions(@meter_collection.grid_carbon_intensity)
    end

    private def process_meter_attributes
      if @meter_attributes.key?(:storage_heaters)
        @storage_heater_setup = StorageHeater.new(attributes(:storage_heaters))
      end
      if @meter_attributes.key?(:solar_pv)
        @solar_pv_setup = SolarPVPanels.new(attributes(:solar_pv))
      end
    end

    private def check_fuel_type(fuel_type)
      throw EnergySparksUnexpectedStateException.new("Unexpected fuel type #{fuel_type}") if [:electricity, :gas].include?(fuel_type)
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
      !@storage_heater_setup.nil?
    end

    def solar_pv_panels?
      !@solar_pv_setup.nil?
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

    # Matches ES AR version
    def display_name
      name.present? ? "#{meter_no} (#{name})" : display_meter_number
    end

    def display_meter_number
      meter_no.present? ? meter_no : meter_type.to_s
    end

    def self.synthetic_combined_meter_mpan_mprn_from_urn(urn, fuel_type)
      if fuel_type == :electricity || fuel_type == :aggregated_electricity
        (90000000000000 + urn.to_i).to_s
      elsif fuel_type == :gas || fuel_type == :aggregated_heat
        (80000000000000 + urn.to_i).to_s
      else
        throw EnergySparksUnexpectedStateException.new('Unexpected fuel_type')
      end
    end
  end
end
