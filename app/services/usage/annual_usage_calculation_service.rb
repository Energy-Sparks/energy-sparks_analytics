module Usage
  class AnnualUsageCalculationService
    DAYSINYEAR = 363

    # Create a service capable of calculating the annual energy usage for a meter
    #
    # To calculate usage for a whole school provide the aggregate electricity
    # meter as the parameter.
    #
    # @param [Dashboard::Meter] analytics_meter the meter to use for calculations
    # @param [Date] asof_date the date to use as the basis for calculations
    #
    # @raise [EnergySparksUnexpectedStateException] if meter isn't an electricity meter
    def initialize(analytics_meter, asof_date=Date.today)
      @meter = analytics_meter
      @asof_date = asof_date
    end

    # Calculate the annual usage over a twelve month period
    #
    # The period is specified using the +period+ parameter
    #
    # Values are not temperature adjusted
    #
    # @param period either :this_year or :last_year
    # @return [CombinedUsageMetric] the calculated usage for the specified period
    def annual_usage(period: :this_year)
      start_date, end_date = dates_for_period(period)
      #using £ not £current as this is historical usage
      CombinedUsageMetric.new(
        kwh: calculate(start_date, end_date, :kwh),
        £: calculate(start_date, end_date, :£),
        co2: calculate(start_date, end_date, :co2)
      )
    end

    # Calculates the annual usage for this year and last year and
    # returns a CombinedUsageMetric with the changes.
    #
    # Values are not temperature adjusted
    #
    # The percentage difference is based on the kwh usage. If you need
    # other behaviour, then just calculate the individual annual usage and
    # derive as needed.
    #
    # If there isn't sufficient data (>2 years) then the method will return nil
    #
    # @return [CombinedUsageMetric] the difference between this year and last year
    def annual_usage_change_since_last_year
      return nil unless has_full_previous_years_worth_of_data?
      this_year = annual_usage(period: :this_year)
      last_year = annual_usage(period: :last_year)
      kwh = this_year.kwh - last_year.kwh
      return CombinedUsageMetric.new(
        kwh: kwh,
        £: this_year.£ - last_year.£,
        co2: this_year.co2 - last_year.co2,
        percent: kwh / last_year.kwh
      )
    end

    #FIXME
    #enough data?  -> needs a year
    #max_days_out_of_date_while_still_relevant == MAX_DAYS_OUT_OF_DATE_FOR_1_YEAR_COMPARISON
    #3*30 days

    #meter_readings_up_to_date_enough
    #max_days_out_of_date_while_still_relevant.nil? ? true : (days_between_today_and_last_meter_date < max_days_out_of_date_while_still_relevant)

    #so if the data is > 90 days out of date, then you won't see any AnnualUsage advice currently
    #enforced via valid_alert?
    #...and on the dashboard you'll get "no recent data"

    # data available from, as per table?
    # this is one year from the start date
    # shown only if there's not enough data

    private

    #:this_year is last 12 months
    #:last_year is previous 12 months
    def dates_for_period(period)
      case period
      when :this_year
        [@asof_date - DAYSINYEAR, @asof_date]
      when :last_year
        prev_date = @asof_date - DAYSINYEAR - 1
        [prev_date - DAYSINYEAR, prev_date]
      else
        raise "Invalid year"
      end
    end

    def has_full_previous_years_worth_of_data?
      start_date, end_date = dates_for_period(:last_year)
      @meter.amr_data.start_date <= start_date
    end

    #Calculate usage values between two dates, returning the
    #results in the specified data type
    #
    #Delegates to the AMR data class for this meter whose kwh_date_range
    #method does the same thing.
    def calculate(start_date, end_date, data_type = :kwh)
      amr_data = @meter.amr_data
      amr_data.kwh_date_range(start_date, end_date, data_type)
    rescue EnergySparksNotEnoughDataException=> e
      nil
    end

  end
end
