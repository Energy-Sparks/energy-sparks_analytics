# frozen_string_literal: true

module UsageBreakdown
  class DayTypeBreakdown
    attr_accessor :holiday, :school_day_closed, :school_day_open, :weekend

    def initialize(school:, fuel_type:)
      @school = school
      @fuel_type = fuel_type
      @holiday = UsageBreakdown::Store.new
      @school_day_closed = UsageBreakdown::Store.new
      @school_day_open = UsageBreakdown::Store.new
      @weekend = UsageBreakdown::Store.new
    end

    def out_of_hours_percent
      holiday.percent + school_day_closed.percent + weekend.percent
    end    



    private

    # Extracted from AlertOutOfHoursBaseUsage::out_of_hours_energy_consumption
    def out_of_hours_energy_consumption_for(data_type)
      chart = ChartManager.new(@school)
      chart.run_standard_chart(breakdown_charts[@fuel_type][data_type], nil, true)
    end

    def calculate_kwh
      daytype_breakdown_kwh = extract_data_from_chart_data(out_of_hours_energy_consumption(:kwh))

      @holidays_kwh         = daytype_breakdown_kwh[Series::DayType::HOLIDAY]
      @weekends_kwh         = daytype_breakdown_kwh[Series::DayType::WEEKEND]
      @schoolday_open_kwh   = daytype_breakdown_kwh[Series::DayType::SCHOOLDAYOPEN]
      @schoolday_closed_kwh = daytype_breakdown_kwh[school_day_closed_key]
      @community_kwh        = daytype_breakdown_kwh[community_name] || 0.0

      # @total_annual_kwh total need to be consistent with £ total for implied tariff calculation
      @total_annual_kwh = @holidays_kwh + @weekends_kwh + @schoolday_open_kwh + @schoolday_closed_kwh + @community_kwh
      @out_of_hours_kwh = @total_annual_kwh - @schoolday_open_kwh

      # will need adjustment for Centrica - TODO
      @out_of_hours_percent = @out_of_hours_kwh / @total_annual_kwh

      @holidays_percent         = @holidays_kwh         / @total_annual_kwh
      @weekends_percent         = @weekends_kwh         / @total_annual_kwh
      @schoolday_open_percent   = @schoolday_open_kwh   / @total_annual_kwh
      @schoolday_closed_percent = @schoolday_closed_kwh / @total_annual_kwh
      @community_percent        = @community_kwh        / @total_annual_kwh
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
