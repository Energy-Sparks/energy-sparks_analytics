require_relative '../../../lib/dashboard/restricted_key_hash.rb'
module Dashboard
  class SubMeters < RestrictedKeyHash
    def self.unique_keys
      standard_meters + simulator_meters
    end

    def self.standard_meters
      %i[
        mains_consume
        storage_heaters
        generation
        self_consume
        mains_plus_self_consume
        export
      ]
    end
    
    def self.simulator_meters
      ElectricitySimulator.sub_meter_keys
    end
  end
end
