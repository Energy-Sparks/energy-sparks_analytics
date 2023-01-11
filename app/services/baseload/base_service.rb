module Baseload
  class BaseService

    #Calculate the co2 per kwh rate for this school, to convert kwh values
    #into co2 emission
    def co2_per_kwh
      rate_calculator.blended_co2_per_kwh
    end

    def rate_calculator
      @rate_calculator ||= BlendedRateCalculator.new(@meter&.meter_collection&.aggregated_electricity_meters || @meter_collection&.aggregated_electricity_meters)
    end

    def baseload_analysis
      @baseload_analysis ||= ElectricityBaseloadAnalysis.new(@meter)
    end

    def validate_meter_collection(meter_collection)
      raise EnergySparksUnexpectedStateException, "School does not have electricity meters" if meter_collection.electricity_meters.empty?
    end

    def validate_meter(analytics_meter)
      raise EnergySparksUnexpectedStateException, "Meter (mpan: #{analytics_meter.id}, fuel_type: #{analytics_meter.fuel_type}) is not an electricity meter" unless analytics_meter.fuel_type == :electricity
    end
  end
end
