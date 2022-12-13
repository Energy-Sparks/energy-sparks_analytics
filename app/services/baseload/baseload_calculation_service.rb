module Baseload
  # This illustrates future direction of analytics interfaces, with
  # the application code calling service classes which delegate
  # to underlying supporting code in the analytics
  #
  # For both the initial and later versions, we'll need
  # to be careful to preserve any checks around whether
  # a school or meter has enough data in order to run a calculation
  #
  # Other sanity checks, e.g. does this school have electricity can
  # be done in the calling code.
  class BaseloadCalculationService
    # Create a service that can calculate the baseload for a specific meter
    #
    # To calculate baseload for a whole school provide the aggregate electricity
    # meter as the parameter.
    #
    # @param [Dashboard::Meter] analytics_meter the meter to use for calculations
    # @param [Date] asof_date the date to use as the basis for calculations
    #
    # @raise [EnergySparksUnexpectedStateException] if meter isn't an electricity meter
    def initialize(analytics_meter, asof_date=Time.zone.today)
      @meter = analytics_meter
      @asof_date = asof_date
    end

    # Calculate average baseload for this meter for the specified period
    #
    # Supported periods are: :year, or :week
    #
    # @param [Symbol] period the period over which to calculate the average
    def average_baseload_kw(period: :year)
      case period
      when :year
        baseload_calculator.average_baseload_kw(@asof_date)
      when :week
        baseload_calculator.average_baseload(@asof_date - 7, @asof_date)
      else
        raise "Invalid period"
      end
    end

    # Calculate the expected annual energy usage based on the
    # average baseload for this school over the last year
    #
    # The usage returns include kwh, co2 emissions and £ costs.
    #
    # @return [CombinedUsageMetric] the calculated usage
    def annual_baseload_usage
      return CombinedUsageMetric.new(
        metric_id: :average_baseload_last_year,
        kwh: average_baseload_last_year_kwh,
        £: average_baseload_last_year_£,
        co2: average_baseload_last_year_co2
      )
    end

    private

    def average_baseload_last_year_kwh
      @annual_average ||= baseload_calculator.annual_average_baseload_kwh(@asof_date)
    end

    def average_baseload_last_year_£
      kwh = average_baseload_last_year_kwh
      kwh * blended_electricity_£_per_kwh
    end

    def average_baseload_last_year_co2
      kwh = average_baseload_last_year_kwh
      kwh * blended_co2_per_kwh
    end

    def meter_collection
      @meter.meter_collection
    end

    def baseload_calculator
      @baseload_calculator ||= ElectricityBaseloadAnalysis.new(@meter)
    end

    def aggregate_meter
      meter_collection.aggregated_electricity_meters
    end

    # The below code could be factored out of existing alert classes into
    # supporting calculation classes similar to how the ElectricityBaseloadAnalysis
    # has been created.
    #
    #
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
      up_to_1_year_ago_start_date = aggregate_meter.amr_data.up_to_1_year_ago
      end_date = aggregate_meter.amr_data.end_date
      blended_rate_date_range(up_to_1_year_ago_start_date, end_date, datatype)
    end

    # Taken from content_base.rb
    # used by above code
    def blended_rate_date_range(start_date, end_date, datatype)
      kwh  = aggregate_meter.amr_data.kwh_date_range(start_date, end_date, :kwh)
      data = aggregate_meter.amr_data.kwh_date_range(start_date, end_date, datatype)
      raise EnergySparksNotEnoughDataException, "zero kWh consumption between #{start_date} and #{end_date}" if kwh == 0.0
      data / kwh
    end
  end
end
