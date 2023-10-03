# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize
module Usage
  class AnnualUsageBreakdownService
    include AnalysableMixin
    def initialize(meter_collection:, fuel_type: :electricity)
      raise 'Invalid fuel type' unless %i[electricity gas storage_heater].include? fuel_type

      @meter_collection = meter_collection
      @fuel_type = fuel_type
    end

    def annual_out_of_hours_kwh
      build_usage_category_usage_metrics!
      calculate_kwh!
      { out_of_hours: @out_of_hours.kwh, total_annual: total_annual_kwh }
    end

    # Calculates a breakdown of the annual usage over the last twelve months
    # Broken down by usage during school day open, closed, weekends and holidays
    #
    # @return [Usage::UsageCategoryBreakdown] the calculated breakdown
    def usage_breakdown
      raise 'Not enough data: at least one years worth of meter data is required' unless enough_data?

      calculate_usage_breakdown
    end

    def enough_data?
      meter_date_range_checker.one_years_data?
    end

    def data_available_from
      meter_date_range_checker.date_when_one_years_data
    end

    private

    def meter_date_range_checker
      @meter_date_range_checker ||= ::Util::MeterDateRangeChecker.new(aggregate_meter, Date.today)
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
      @usage_category_breakdown ||= Usage::AnnualUsageCategoryBreakdown.new(
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

    def school_day_closed_key
      @school_day_closed_key ||= @fuel_type == :storage_heater ? Series::DayType::STORAGE_HEATER_CHARGE : Series::DayType::SCHOOLDAYCLOSED
    end

    # rubocop:disable Layout/LineLength
    def calculate_kwh!
      daytype_breakdown_kwh = extract_data_from_chart_data(:kwh)
      @holiday.kwh              = daytype_breakdown_kwh[:x_data][Series::DayType::HOLIDAY].first || 0
      @weekend.kwh              = daytype_breakdown_kwh[:x_data][Series::DayType::WEEKEND].first || 0
      @school_day_open.kwh       = daytype_breakdown_kwh[:x_data][Series::DayType::SCHOOLDAYOPEN].first || 0
      @school_day_closed.kwh     = daytype_breakdown_kwh[:x_data][school_day_closed_key].first || 0
      @community.kwh             = daytype_breakdown_kwh[:x_data][community_key]&.first || 0.0
      @out_of_hours.kwh = total_annual_kwh - @school_day_open.kwh
    end
    # rubocop:enable Layout/LineLength

    def calculate_percent!
      @holiday.percent = @holiday.kwh / total_annual_kwh
      @weekend.percent = @weekend.kwh / total_annual_kwh
      @school_day_open.percent = @school_day_open.kwh / total_annual_kwh
      @school_day_closed.percent = @school_day_closed.kwh / total_annual_kwh
      @community.percent = @community.kwh / total_annual_kwh
      @out_of_hours.percent = @holiday.percent + @weekend.percent + @school_day_closed.percent + @community.percent
    end

    # Extracted from AlertOutOfHoursBaseUsage#calculate_£
    # rubocop:disable Layout/LineLength
    def calculate_pounds_sterling!
      daytype_breakdown_pounds_sterling = extract_data_from_chart_data(:pounds_sterling)

      @holiday.£          = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::HOLIDAY].first || 0.0
      @weekend.£          = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::WEEKEND].first || 0.0
      @school_day_open.£   = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::SCHOOLDAYOPEN].first || 0.0
      @school_day_closed.£ = daytype_breakdown_pounds_sterling[:x_data][school_day_closed_key].first || 0.0
      @community.£         = daytype_breakdown_pounds_sterling[:x_data][community_key]&.first || 0.0

      # @total_annual_£ total need to be consistent with kwh total for implied tariff calculation
      @out_of_hours.£ = total_annual_pounds_sterling - @school_day_open.£
    end
    # rubocop:enable Layout/LineLength

    # rubocop:disable Layout/LineLength
    def calculate_co2!
      daytype_breakdown_co2 = extract_data_from_chart_data(:co2)

      @holiday.co2          = daytype_breakdown_co2[:x_data][Series::DayType::HOLIDAY].first || 0.0
      @weekend.co2          = daytype_breakdown_co2[:x_data][Series::DayType::WEEKEND].first || 0.0
      @school_day_open.co2   = daytype_breakdown_co2[:x_data][Series::DayType::SCHOOLDAYOPEN].first || 0.0
      @school_day_closed.co2 = daytype_breakdown_co2[:x_data][school_day_closed_key].first || 0.0
      @community.co2         = daytype_breakdown_co2[:x_data][community_key]&.first || 0.0

      @out_of_hours.co2 = total_annual_co2 - @school_day_open.co2
    end
    # rubocop:enable Layout/LineLength

    def total_annual_pounds_sterling
      @holiday.£ +
        @weekend.£ +
        @school_day_open.£ +
        @school_day_closed.£ +
        @community.£
    end

    def total_annual_kwh
      @holiday.kwh + @weekend.kwh + @school_day_open.kwh + @school_day_closed.kwh + @community.kwh
    end

    def total_annual_co2
      @holiday.co2 + @weekend.co2 + @school_day_open.co2 + @school_day_closed.co2 + @community.co2
    end

    def extract_data_from_chart_data(data_type)
      chart = ChartManager.new(@meter_collection)
      chart.run_standard_chart(breakdown_charts[@fuel_type][data_type], nil, true, provide_advice: false)
    end

    # rubocop:disable Metrics/MethodLength
    def breakdown_charts
      {
        electricity:
          {
            kwh: :alert_daytype_breakdown_electricity_kwh,
            co2: :alert_daytype_breakdown_electricity_co2,
            pounds_sterling: :alert_daytype_breakdown_electricity_£,
            £current: :alert_daytype_breakdown_electricity_£current
          },
        gas:
          {
            kwh: :alert_daytype_breakdown_gas_kwh,
            co2: :alert_daytype_breakdown_gas_co2,
            pounds_sterling: :alert_daytype_breakdown_gas_£,
            £current: :alert_daytype_breakdown_gas_£current
          },
        storage_heater:
          {
            kwh: :alert_daytype_breakdown_storage_heater_kwh,
            co2: :alert_daytype_breakdown_storage_heater_co2,
            pounds_sterling: :alert_daytype_breakdown_storage_heater_£,
            £current: :alert_daytype_breakdown_storage_heater_£current
          }
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize
