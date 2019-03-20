module Dashboard
  # meter: holds basic information descrbing a meter and hald hourly AMR data associated with it
  class Meter
    include Logging

    # Extra fields - potentially a concern or mix-in
    attr_reader :fuel_type, :meter_collection
    attr_reader :solar_pv_installation, :storage_heater_setup, :sub_meters
    attr_reader :meter_correction_rules, :model_cache
    attr_accessor :amr_data,  :floor_area, :number_of_pupils

    # Energy Sparks activerecord fields:
    attr_reader :active, :created_at, :meter_no, :meter_type, :school, :updated_at, :mpan_mprn
    attr_accessor :id, :name, :external_meter_id
    # enum meter_type: [:electricity, :gas]

    def initialize(meter_collection, amr_data, type, identifier, name,
                    floor_area = nil, number_of_pupils = nil,
                    solar_pv_installation = nil,
                    storage_heater_config = nil, # now redundant PH 20Mar2019
                    external_meter_id = nil,
                    meter_attributes = MeterAttributes)
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

    private def process_meter_attributes
      unless @meter_attributes.attributes(self, :storage_heaters).nil?
        @storage_heater_setup = StorageHeater.new(@meter_attributes.attributes(self, :storage_heaters))
      end
    end

    private def check_fuel_type(fuel_type)
      throw EnergySparksUnexpectedStateException.new("Unexpected fuel type #{fuel_type}") if [:electricity, :gas].include?(fuel_type)
    end

    def to_s
      @mpan_mprn.to_s + ':' + @fuel_type.to_s + 'x' + (@amr_data.nil? ? '0' : @amr_data.length.to_s)
    end

    def attributes(type)
      @meter_attributes.attributes(self, type)
    end

    def all_attributes
      @meter_attributes.attributes(self)
    end

    def storage_heater?
      !@storage_heater_setup.nil?
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
      function = @meter_attributes.attributes(self, :function)
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

    def add_correction_rule(rule)
      throw EnergySparksUnexpectedStateException.new('Unexpected nil correction') if rule.nil?
      @meter_correction_rules.push(rule)
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
