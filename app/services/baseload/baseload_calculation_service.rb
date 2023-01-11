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
  class BaseloadCalculationService < BaseService
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
      validate_meter(analytics_meter)
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
        baseload_analysis.average_annual_baseload_kw(@asof_date)
      when :week
        baseload_analysis.average_baseload_kw(@asof_date - 6, @asof_date)
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
        kwh: average_baseload_last_year_kwh,
        £: average_baseload_last_year_£,
        co2: average_baseload_last_year_co2
      )
    end

    private

    def average_baseload_last_year_kwh
      @annual_average ||= baseload_analysis.annual_average_baseload_kwh(@asof_date)
    end

    def average_baseload_last_year_£
      baseload_analysis.scaled_annual_baseload_cost_£(:£, @asof_date)
    end

    def average_baseload_last_year_co2
      kwh = average_baseload_last_year_kwh
      kwh * co2_per_kwh
    end

    def meter_collection
      @meter.meter_collection
    end

  end
end
