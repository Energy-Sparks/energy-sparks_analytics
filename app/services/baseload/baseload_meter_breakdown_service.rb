module Baseload
  # Calculates a breakdown of the baseload for all electricity meters in a school
  #
  # The breakdown includes the
  # - average annual baseload for each meter
  # - the cost associated with that baseload
  # - the % contribution towards the total baseload
  #
  # The service could easily be adapted to report based on a different period
  class BaseloadMeterBreakdownService
    def initialize(meter_collection)
      validate_meter_collection(meter_collection)
      @meter_collection = meter_collection
    end

    # @return [MeterBaseloadBreakdown] the calculated breakdown
    def calculate_breakdown
      MeterBaseloadBreakdown.new(meter_breakdown: calculate_percentage_baseload)
    end

    private

    #Taken from AdviceBaseload
    def calculate_percentage_baseload
      average_baseload_last_year = calculate_average_baseload_last_year

      total_baseload_kw = average_baseload_last_year.values.map { |v| v[:kw] }.sum

      average_baseload_last_year.transform_values do |v|
        {
          kw:       v[:kw],
          £:        v[:£],
          percent:  v[:kw] / total_baseload_kw
        }
      end
    end

    #Taken from AdviceBaseload
    def calculate_average_baseload_last_year
      electricity_meters.map do |meter|
        [
          meter.mpan_mprn,
          {
            kw: meter.amr_data.average_baseload_kw_date_range(sheffield_solar_pv: meter.sheffield_simulated_solar_pv_panels?),
            £: ElectricityBaseloadAnalysis.new(meter).scaled_annual_baseload_cost_£(:£)
          }
        ]
      end.to_h
    end

    def electricity_meters
      @meter_collection.electricity_meters
    end

    def validate_meter_collection(meter_collection)
      raise EnergySparksUnexpectedStateException, "School does not have electricity meters" if meter_collection.electricity_meters == nil
    end

  end
end
