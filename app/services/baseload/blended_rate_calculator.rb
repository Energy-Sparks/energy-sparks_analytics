#TODO this should sit in a different package as its more general purpose. Move to costs package?
#
#TODO there's other code in the amr_data class that
#creates blended rates, perhaps that should be exposed here?
module Baseload

  # Calculates rates (£/kwh or co2/kwh) for an aggregate meter
  #
  # Uses up to a years worth of consumption data
  class BlendedRateCalculator
    def initialize(aggregate_meter)
      @aggregate_meter = aggregate_meter
    end

    # Taken from ElectricityCostCo2Mixin
    def blended_electricity_£_per_kwh
      @blended_electricity_£_per_kwh ||= blended_rate(:£)
    end

    # Taken from ElectricityCostCo2Mixin
    def blended_co2_per_kwh
      @blended_co2_per_kwh ||= blended_rate(:co2)
    end

    # Taken from content_base.rb
    # used by above code
    def blended_rate(datatype = :£)
      up_to_1_year_ago_start_date = @aggregate_meter.amr_data.up_to_1_year_ago
      end_date = @aggregate_meter.amr_data.end_date
      blended_rate_date_range(up_to_1_year_ago_start_date, end_date, datatype)
    end

    # Taken from content_base.rb
    # used by above code
    def blended_rate_date_range(start_date, end_date, datatype)
      kwh  = @aggregate_meter.amr_data.kwh_date_range(start_date, end_date, :kwh)
      data = @aggregate_meter.amr_data.kwh_date_range(start_date, end_date, datatype)
      raise EnergySparksNotEnoughDataException, "zero kWh consumption between #{start_date} and #{end_date}" if kwh == 0.0
      data / kwh
    end

  end
end
