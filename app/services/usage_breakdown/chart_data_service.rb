module UsageBreakdown
  class ChartDataService
    def self.extract_data_from_chart_data(school, fuel_type, data_type)
      chart = ChartManager.new(school)
      chart.run_standard_chart(breakdown_charts[fuel_type][data_type], nil, true)
    end

    def self.breakdown_charts
      {
        electricity:
          {
            kwh:      :alert_daytype_breakdown_electricity_kwh,
            co2:      :alert_daytype_breakdown_electricity_co2,
            pounds_sterling:        :alert_daytype_breakdown_electricity_£,
            £current: :alert_daytype_breakdown_electricity_£current,
          },
        gas:
          {
            kwh:      :alert_daytype_breakdown_gas_kwh,
            co2:      :alert_daytype_breakdown_gas_co2,
            pounds_sterling:        :alert_daytype_breakdown_gas_£,
            £current: :alert_daytype_breakdown_gas_£current
          }
      }
    end
  end
end