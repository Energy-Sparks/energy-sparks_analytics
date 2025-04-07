require_rel './meter.rb'

module Dashboard
  class AggregateMeter < Meter
    def initialize(meter_collection:, amr_data:, type:, identifier:, name:,
                   floor_area: nil, number_of_pupils: nil,
                   solar_pv_installation: nil,
                   storage_heater_config: nil, # now redundant PH 20Mar2019
                   external_meter_id: nil,
                   dcc_meter: false,
                   constituent_meters: [],
                   meter_attributes: {})
      super(meter_collection:,
            amr_data:,
            type:,
            identifier:,
            name:,
            floor_area:,
            number_of_pupils:,
            solar_pv_installation:,
            storage_heater_config:,
            external_meter_id:,
            dcc_meter:,
            meter_attributes: {})
      @constituent_meters = constituent_meters
      @has_sheffield_solar_pv = constituent_meters.any?(&:sheffield_simulated_solar_pv_panels?)
      @has_metered_solar = constituent_meters.any?(&:solar_pv_real_metering?)
      add_aggregate_partial_meter_coverage_component(list_of_meters.map(&:partial_meter_coverage))
    end

    def sheffield_simulated_solar_pv_panels?
      @has_sheffield_solar_pv || super
    end

    def solar_pv_real_metering?
      @has_metered_solar || super
    end

    # must be called immediately after construction
    def set_constituent_meters(list_of_meters)
      @constituent_meters = list_of_meters
    end

    def aggregate_meter?
      true
    end
  end
end
