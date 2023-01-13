# frozen_string_literal: true

module UsageBreakdown
  class DayTypeBreakdown
    attr_accessor :holidays, :school_day_closed, :school_day_open, :weekends, :out_of_hours

    def initialize(school:, fuel_type: :electricity)
      @school = school
      @fuel_type = fuel_type
      @holidays = UsageBreakdown::Store.new
      @school_day_closed = UsageBreakdown::Store.new
      @school_day_open = UsageBreakdown::Store.new
      @out_of_hours = UsageBreakdown::Store.new
      @weekends = UsageBreakdown::Store.new
    end

    def out_of_hours_percent
      holidays.percent + school_day_closed.percent + weekends.percent
    end

    def calculate_kwh!
      daytype_breakdown_kwh = energy_consumption_for(:kwh)

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

    def total_annual_kwh
      holidays.kwh + weekends.kwh + school_day_open.kwh + school_day_closed.kwh # + community.kwh
    end

    private

    # Extracted from AlertOutOfHoursBaseUsage::out_of_hours_energy_consumption
    def energy_consumption_for(data_type)
      chart = ChartManager.new(@school)
      chart.run_standard_chart(breakdown_charts[@fuel_type][data_type], nil, true)



    end

    def breakdown_charts
      # extracted from 
      # AlertOutOfHoursElectricityUsage::breakdown_charts
      # AlertOutOfHoursGasUsage::breakdown_charts
      {
        electricity:
          {
            kwh:      :alert_daytype_breakdown_electricity_kwh,
            co2:      :alert_daytype_breakdown_electricity_co2,
            £:        :alert_daytype_breakdown_electricity_£,
            £current: :alert_daytype_breakdown_electricity_£current,
          },
        gas:
          {
            kwh:      :alert_daytype_breakdown_gas_kwh,
            co2:      :alert_daytype_breakdown_gas_co2,
            £:        :alert_daytype_breakdown_gas_£,
            £current: :alert_daytype_breakdown_gas_£current
          }
      }
    end
  end
end
