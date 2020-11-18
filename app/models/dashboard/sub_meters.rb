module Dashboard
  # ensure sub meter enumeration constrained to fixed list - defensive
  class SubMeters < Hash
    def [](sub_meter_type)
      raise EnergySparksUnexpectedStateException, "Unknown_sub meter type #{sub_meter_type}" unless permissible_sub_meter_type(sub_meter_type)
      
      super(sub_meter_type)
    end

    def self.permissible_sub_meter_types
      %i[
        mains_consume
        storage_heaters
        generation
        self_consume
        mains_plus_self_consume export
      ]
    end

    private

    def permissible_sub_meter_type(sub_meter_type)
      self.class.permissible_sub_meter_types.include?(sub_meter_type)
    end
  end
end
