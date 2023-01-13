# frozen_string_literal: true

module UsageBreakdown
  class DayTypeBreakdown
    # {
    #   :holiday => (kwh, £current, co2, %)
    #   :school_day_closed => (kwh, £current, co2, %)
    #   :school_day_open => ...
    #   :weekend => ...
    # }
    def initialize; end

    def holiday; end

    def school_day_closed; end

    def school_day_open; end

    def weekend; end

    def percentage_out_of_hours
      # holiday.percent + school_day_closed.percent + weekend.percent
    end
  end
end
