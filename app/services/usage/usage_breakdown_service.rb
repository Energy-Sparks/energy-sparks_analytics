# frozen_string_literal: true

module Usage
  # Calculates a breakdown of the out of ours usage, broken down by usage
  # during school day open, closed, weekends and holidays
  #
  # Uses up to a years worth of data to perform calculations.
  #
  # Note: if a school has less than a years worth of data then the results
  # produced by this service are not suitable for benchmarking, as our
  # benchmarks are based on average consumption across a year.
  class UsageBreakdownService
    include AnalysableMixin
    def initialize(meter_collection:, fuel_type: :electricity, asof_date: Date.today)
      raise 'Invalid fuel type' unless %i[electricity gas storage_heater].include? fuel_type

      @meter_collection = meter_collection
      @fuel_type = fuel_type
      @asof_date = asof_date
    end

    # Calculates just the kwh consumed out of hours. "Out of hours" is defined
    # as any period when the school is closed. This includes periods of community use.
    def out_of_hours_kwh
      build_usage_category_usage_metrics!
      calculate_kwh!
      { out_of_hours: @out_of_hours.kwh, total: total_kwh }
    end

    # Calculates a breakdown of the out of ours usage using up to a full years
    # worth of data. Broken down by usage during school day open, closed,
    # weekends, holidays and community use.
    #
    # Usage may be zero for some categories because they don't occur during the
    # available data.
    #
    # Costs are based on the tariffs in use at the time of consumption.
    #
    # @return [Usage::UsageBreakdown] the calculated breakdown
    def usage_breakdown
      raise 'Not enough data: at least one week of meter data is required' unless enough_data?

      calculate_usage_breakdown
    end

    def enough_data?
      meter_date_range_checker.at_least_x_days_data?(7)
    end

    def data_available_from
      meter_date_range_checker.date_when_enough_data_available(7)
    end

    private

    def meter_date_range_checker
      @meter_date_range_checker ||= ::Util::MeterDateRangeChecker.new(aggregate_meter, @asof_date)
    end

    def aggregate_meter
      @aggregate_meter ||= case @fuel_type
                           when :electricity then @meter_collection.aggregated_electricity_meters
                           when :gas then @meter_collection.aggregated_heat_meters
                           when :storage_heater then @meter_collection.storage_heater_meter
                           end
    end

    def calculate_usage_breakdown
      build_usage_category_usage_metrics!
      calculate_kwh!
      calculate_percent!
      calculate_pounds_sterling!
      calculate_co2!

      build_usage_category_breakdown
    end

    def build_usage_category_breakdown
      @build_usage_category_breakdown ||= Usage::UsageBreakdown.new(
        holiday: @holiday,
        school_day_closed: @school_day_closed,
        school_day_open: @school_day_open,
        weekend: @weekend,
        out_of_hours: @out_of_hours,
        community: @community,
        fuel_type: @fuel_type
      )
    end

    def build_usage_category_usage_metrics!
      @holiday = CombinedUsageMetric.new
      @school_day_closed = CombinedUsageMetric.new
      @school_day_open = CombinedUsageMetric.new
      @out_of_hours = CombinedUsageMetric.new
      @weekend = CombinedUsageMetric.new
      @community = CombinedUsageMetric.new
    end

    def community_key
      OpenCloseTime.humanize_symbol(OpenCloseTime::COMMUNITY)
    end

    def calculate_breakdown(unit = :kwh)
      CalculateAggregateValues.new(@meter_collection).day_type_breakdown(:up_to_a_year, @fuel_type, unit)
    end

    def calculate_kwh!
      day_type_breakdown = calculate_breakdown(:kwh)

      @holiday.kwh = day_type_breakdown[Series::DayType::HOLIDAY] || 0.0
      @weekend.kwh = day_type_breakdown[Series::DayType::WEEKEND] || 0.0
      @school_day_open.kwh       = day_type_breakdown[Series::DayType::SCHOOLDAYOPEN] || 0.0
      @school_day_closed.kwh     = day_type_breakdown[Series::DayType::SCHOOLDAYCLOSED] || 0.0
      @community.kwh             = day_type_breakdown[community_key] || 0.0

      @out_of_hours.kwh = total_kwh - @school_day_open.kwh
    end

    def calculate_percent!
      @holiday.percent = @holiday.kwh / total_kwh
      @weekend.percent = @weekend.kwh / total_kwh
      @school_day_open.percent = @school_day_open.kwh / total_kwh
      @school_day_closed.percent = @school_day_closed.kwh / total_kwh
      @community.percent = @community.kwh / total_kwh
      @out_of_hours.percent = @holiday.percent + @weekend.percent + @school_day_closed.percent + @community.percent
    end

    def calculate_pounds_sterling!
      day_type_breakdown = calculate_breakdown(:£)

      @holiday.£ = day_type_breakdown[Series::DayType::HOLIDAY] || 0.0
      @weekend.£ = day_type_breakdown[Series::DayType::WEEKEND] || 0.0
      @school_day_open.£       = day_type_breakdown[Series::DayType::SCHOOLDAYOPEN] || 0.0
      @school_day_closed.£     = day_type_breakdown[Series::DayType::SCHOOLDAYCLOSED] || 0.0
      @community.£             = day_type_breakdown[community_key] || 0.0

      @out_of_hours.£ = total_pounds_sterling - @school_day_open.£
    end

    def calculate_co2!
      day_type_breakdown = calculate_breakdown(:co2)

      @holiday.co2 = day_type_breakdown[Series::DayType::HOLIDAY] || 0.0
      @weekend.co2 = day_type_breakdown[Series::DayType::WEEKEND] || 0.0
      @school_day_open.co2       = day_type_breakdown[Series::DayType::SCHOOLDAYOPEN] || 0.0
      @school_day_closed.co2     = day_type_breakdown[Series::DayType::SCHOOLDAYCLOSED] || 0.0
      @community.co2             = day_type_breakdown[community_key] || 0.0
      @out_of_hours.co2 = total_co2 - @school_day_open.co2
    end

    def total_pounds_sterling
      @holiday.£ +
        @weekend.£ +
        @school_day_open.£ +
        @school_day_closed.£ +
        @community.£
    end

    def total_kwh
      @holiday.kwh + @weekend.kwh + @school_day_open.kwh + @school_day_closed.kwh + @community.kwh
    end

    def total_co2
      @holiday.co2 + @weekend.co2 + @school_day_open.co2 + @school_day_closed.co2 + @community.co2
    end
  end
end
