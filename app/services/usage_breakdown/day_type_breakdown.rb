# frozen_string_literal: true

module UsageBreakdown
  class DayTypeBreakdown
    attr_reader :holidays, :school_day_closed, :school_day_open, :weekends, :out_of_hours

    def initialize(school:, fuel_type: :electricity)
      @school = school
      @fuel_type = fuel_type
      build_day_type_breakdowns
    end

    def out_of_hours_percent
      holidays.percent + school_day_closed.percent + weekends.percent
    end

    def average_out_of_hours_percent
      BenchmarkMetrics::AVERAGE_OUT_OF_HOURS_PERCENT
    end

    def total_annual_pounds_sterling
      holidays.pounds_sterling + weekends.pounds_sterling + school_day_open.pounds_sterling + school_day_closed.pounds_sterling #+ @community_£
    end

    def total_annual_kwh
      holidays.kwh + weekends.kwh + school_day_open.kwh + school_day_closed.kwh # + community.kwh
    end

    def total_annual_co2
      holidays.co2 + weekends.co2 + school_day_open.co2 + school_day_closed.co2 #+ @community_co2
    end

    private

    def build_day_type_breakdowns
      build_stores!

      calculate_kwh!
      calculate_pounds_sterling!
      calculate_co2!
    end

    def build_stores!
      @holidays = UsageBreakdown::Store.new
      @school_day_closed = UsageBreakdown::Store.new
      @school_day_open = UsageBreakdown::Store.new
      @out_of_hours = UsageBreakdown::Store.new
      @weekends = UsageBreakdown::Store.new
    end

    def calculate_kwh!
      daytype_breakdown_kwh = extract_data_from_chart_data(:kwh)

      holidays.kwh             = daytype_breakdown_kwh[:x_data][Series::DayType::HOLIDAY].first || 0
      weekends.kwh             = daytype_breakdown_kwh[:x_data][Series::DayType::WEEKEND].first || 0
      school_day_open.kwh      = daytype_breakdown_kwh[:x_data][Series::DayType::SCHOOLDAYOPEN].first || 0
      school_day_closed.kwh    = daytype_breakdown_kwh[:x_data][Series::DayType::SCHOOLDAYCLOSED].first || 0
      # @community_kwh        = daytype_breakdown_kwh[community_name] || 0.0

      holidays.percent         = @holidays.kwh         / total_annual_kwh
      weekends.percent         = @weekends.kwh         / total_annual_kwh
      school_day_open.percent   = @school_day_open.kwh   / total_annual_kwh
      school_day_closed.percent = @school_day_closed.kwh / total_annual_kwh
      # # community_percent        = @community_kwh        / @total_annual_kwh
    
      out_of_hours.kwh = total_annual_kwh - school_day_open.kwh
      out_of_hours.percent = holidays.percent + weekends.percent + school_day_closed.percent
    end

    # Extracted from AlertOutOfHoursBaseUsage#calculate_£
    def calculate_pounds_sterling!
      daytype_breakdown_pounds_sterling = extract_data_from_chart_data(:pounds_sterling)  

      holidays.pounds_sterling         = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::HOLIDAY].first
      weekends.pounds_sterling         = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::WEEKEND].first
      school_day_open.pounds_sterling   = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::SCHOOLDAYOPEN].first
      school_day_closed.pounds_sterling = daytype_breakdown_pounds_sterling[:x_data][Series::DayType::SCHOOLDAYCLOSED].first
      # @community.pounds_sterling        = daytype_breakdown_£[community_name] || 0.0  

      # @total_annual_£ total need to be consistent with kwh total for implied tariff calculation
      out_of_hours.pounds_sterling = total_annual_pounds_sterling - school_day_open.pounds_sterling
    end

    def calculate_co2!
      daytype_breakdown_co2 = extract_data_from_chart_data(:co2)

      holidays.co2          = daytype_breakdown_co2[:x_data][Series::DayType::HOLIDAY].first
      weekends.co2          = daytype_breakdown_co2[:x_data][Series::DayType::WEEKEND].first
      school_day_open.co2   = daytype_breakdown_co2[:x_data][Series::DayType::SCHOOLDAYOPEN].first
      school_day_closed.co2 = daytype_breakdown_co2[:x_data][Series::DayType::SCHOOLDAYCLOSED].first
      # community_co2        = daytype_breakdown_co2[community_name] || 0.0  

      out_of_hours.co2 = total_annual_co2 - school_day_open.co2
    end

    # Extracted from AlertOutOfHoursBaseUsage::out_of_hours_energy_consumption
    def extract_data_from_chart_data(data_type)
      UsageBreakdown::ChartDataService.extract_data_from_chart_data(@school, @fuel_type, data_type)
    end
  end
end
