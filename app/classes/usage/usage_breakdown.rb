# frozen_string_literal: true

module Usage
  class UsageBreakdown
    attr_reader :holiday, :school_day_closed, :school_day_open, :weekend, :out_of_hours, :community

    def initialize(
      holiday:,
      school_day_closed:,
      school_day_open:,
      weekend:,
      out_of_hours:,
      community:,
      fuel_type:
    )
      @holiday = holiday
      @school_day_closed = school_day_closed
      @school_day_open = school_day_open
      @weekend = weekend
      @out_of_hours = out_of_hours
      @community = community
      @fuel_type = fuel_type
    end

    def total
      CombinedUsageMetric.new(
        kwh: total_annual_kwh,
        co2: total_annual_co2,
        £: total_annual_£
      )
    end

    private

    def total_annual_£
      holiday.£ +
        weekend.£ +
        school_day_open.£ +
        school_day_closed.£ +
        community.£
    end

    def total_annual_co2
      @holiday.co2 + @weekend.co2 + @school_day_open.co2 + @school_day_closed.co2 + @community.co2
    end

    def total_annual_kwh
      @holiday.kwh + @weekend.kwh + @school_day_open.kwh + @school_day_closed.kwh + @community.kwh
    end
  end
end
