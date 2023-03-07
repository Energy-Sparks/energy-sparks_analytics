module Costs
  class TariffInformationService
    # Creates a service capable of providing information about the
    # accounting tariffs for a specific meter, between 2 dates
    #
    # Can be used to get information for a single meter, or by supplying the
    # aggregate meter, the whole school.
    #
    # The analysis start/end date define the ideal period for which information
    # will be provided. However if the meter has less data, then the actual
    # meter dates will be used instead.
    def initialize(analytics_meter, analysis_start_date, analyis_end_date)
      @meter = analytics_meter
      @analysis_start_date = analysis_start_date
      @analyis_end_date = analyis_end_date
      @meter_start_date = [@meter.amr_data.start_date, analysis_start_date].max
      @meter_end_date   = [@meter.amr_data.end_date,   analyis_end_date].min
    end

    #Are we analysing less data than we have for the ideal range?
    def incomplete_coverage?
      @meter.amr_data.start_date > @analysis_start_date || @meter.amr_data.end_date != @analyis_end_date
    end

    #For the analysed period, what % of that time do we have real tariffs?
    #
    #Will be 0.0 if periods_with_tariffs is an empty array
    def percentage_with_real_tariffs
      @percent_real ||= calculate_percent_real
    end

    def periods_with_tariffs
      #find missing billing period and extract earliest and latest dates
      @tariff_periods ||= find_billing_periods(true).map do |period_block|
        [period_block.first[0], period_block.last[0]]
      end
    end

    def periods_with_missing_tariffs
      #find missing billing period and extract earliest and latest dates
      @missing_periods ||= find_billing_periods(false).map do |period_block|
        [period_block.first[0], period_block.last[0]]
      end
    end

    private

    def calculate_percent_real
      count = billing_periods.values.count { |missing| missing }
      count.to_f / (@meter_end_date - @meter_start_date + 1)
    end

    #Find the ranges where we don't have fully real tariffs for a school
    #@return an Enumerator which will yield one or more arrays, each of which contains run of dates
    def find_billing_periods(real_tariffs = false)
      # split periods of real and non-real default system-wide tariffs
      grouped_periods = billing_periods.to_a.slice_when do |prev, curr|
        prev[1] != curr[1]
      end
      # select date ranges based on whether they contain real, or
      # non-real default system-wide tariffs
      missing = grouped_periods.select { |period| period[0][1] == real_tariffs }
    end


    def billing_periods
      @billing_periods ||= calculate_billing_periods
    end

    #Returns an hash of day => boolean
    #the boolean value indicates whether the tariff on that date is a
    def calculate_billing_periods
      count = (billing_calculation_start_date..@meter_end_date).to_a.map do |date|
        # these are tristate true, false and :mixed (combined meters)
        cost = accounting_tariff.one_days_cost_data(date)
        [
          date,
          fully_real_tariff?(cost.system_wide) && fully_real_tariff?(cost.default)
        ]
      end.to_h
    end

    def accounting_tariff
      @meter.amr_data.accounting_tariff
    end

    def fully_real_tariff?(type)
      type == false && type != :mixed
    end

    def billing_calculation_start_date
      twenty_five_months = 30 + 2 * 365 # approx 25 months, covers billing period of comparison chart and table
      [@meter_end_date - twenty_five_months, @meter_start_date].max
    end

  end
end
