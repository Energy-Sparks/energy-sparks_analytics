class DashboardConfiguration
  DASHBOARD_PAGE_GROUPS = {  # dashboard page groups: defined page, and charts on that page
    pupil_analysis_page: {
      name:   'Pupil Analysis',
      sub_pages:  [
        {
          name:     'Electricity',
          sub_pages:  [
            { name: 'kWh',    charts: %i[pupil_dashboard_group_by_week_electricity_kwh] },
            { name: 'Cost',   charts: %i[pupil_dashboard_group_by_week_electricity_£] },
            { name: 'CO2',    charts: %i[pupil_dashboard_group_by_week_electricity_co2] },
            { name: 'Pie',    charts: %i[pupil_dashboard_daytype_breakdown_electricity] },
            {
              name: 'Bar',
              sub_pages: [
                { name: 'Bench',   charts: %i[pupil_dashboard_electricity_benchmark] },
                { name: 'Week',    charts: %i[pupil_dashboard_group_by_week_electricity_£] },
                { name: 'Year',    charts: %i[pupil_dashboard_electricity_longterm_trend_£] }
              ]
            },
            {
              name: 'Line',
              sub_pages: [
                { name: 'Base',   charts: %i[pupil_dashboard_baseload_lastyear] },
                { name: '7days',  charts: %i[pupil_dashboard_intraday_line_electricity_last7days] }
              ]
            }
          ],
        },
        {
          name:     'Gas',
          sub_pages:  [
            { name: 'kWh',    charts: %i[pupil_dashboard_group_by_week_gas_kwh] },
            { name: 'Cost',   charts: %i[pupil_dashboard_group_by_week_gas_£] },
            { name: 'CO2',    charts: %i[pupil_dashboard_group_by_week_gas_co2] },
            { name: 'Pie',    charts: %i[pupil_dashboard_daytype_breakdown_gas] },
            {
              name: 'Bar',
              sub_pages: [
                { name: 'Bench',   charts: %i[pupil_dashboard_gas_benchmark] },
                { name: 'Week',    charts: %i[pupil_dashboard_group_by_week_gas_£] },
                { name: 'Year',    charts: %i[pupil_dashboard_gas_longterm_trend_£] }
              ]
            },
            { name: 'Line',  charts: %i[pupil_dashboard_intraday_line_gas_last7days] }
          ],
        },
        {
          name:     'Storage Heaters',
          sub_pages:  [
            { name: 'kWh',    charts: %i[pupil_dashboard_group_by_week_storage_heaters_kwh] },
            { name: 'Cost',   charts: %i[pupil_dashboard_group_by_week_storage_heaters_£] },
            { name: 'CO2',    charts: %i[pupil_dashboard_group_by_week_storage_heaters_co2] },
            { name: 'Pie',    charts: %i[pupil_dashboard_daytype_breakdown_storage_heaters] },
            {
              name: 'Bar',
              sub_pages: [
                { name: 'Bench',   charts: %i[pupil_dashboard_storage_heaters_benchmark] },
                { name: 'Week',    charts: %i[pupil_dashboard_group_by_week_storage_heaters_£] },
                { name: 'Year',    charts: %i[pupil_dashboard_storage_heaters_longterm_trend_£] }
              ]
            },
            { name: 'Line',  charts: %i[pupil_dashboard_intraday_line_storage_heaters_last7days] },
          ],
        },
        {
          name:     'Electricity+Solar PV',
          sub_pages:  [
            { name: 'kWh',    charts: %i[pupil_dashboard_group_by_week_electricity_kwh] },
            { name: 'Solar',  charts: %i[pupil_dashboard_solar_pv_monthly] },
            { name: 'Pie',    charts: %i[pupil_dashboard_daytype_breakdown_electricity] },
            {
              name: 'Bar',
              sub_pages: [
                { name: 'Bench',   charts: %i[pupil_dashboard_solar_pv_benchmark] },
                { name: 'Week',    charts: %i[pupil_dashboard_group_by_week_electricity_£] },
                { name: 'Year',    charts: %i[pupil_dashboard_electricity_longterm_trend_£] }
              ]
            },
            {
              name: 'Line',
              sub_pages: [
                { name: 'Base',   charts: %i[pupil_dashboard_baseload_lastyear] },
                { name: '7days',  charts: %i[pupil_dashboard_intraday_line_electricity_last7days] }
              ]
            }
          ],
        }
      ],
    },
    simulator:                {
                                name:   'Simulator Test',
                                charts: [
                                  :electricity_simulator_pie,
                                   {
                                    type: :simulator_group_by_week_comparison,
                                    name: 'Comparison of Simulator and Actual Electricity Consumption by Week of the Year',
                                    advice_text: true,
                                    chart_group: {
                                      link_y_axis: true,
                                      layout: :horizontal,
                                      charts: %i[
                                        group_by_week_electricity_simulator
                                        group_by_week_electricity_actual_for_simulator_comparison
                                      ]
                                    }
                                  },
                                  {
                                    type: :simulator_group_by_day_of_week_comparison,
                                    name: 'Comparison of Simulator and Actual Electricity Consumption by Day of the Week for the Last Year',
                                    advice_text: true,
                                    chart_group: {
                                      link_y_axis: true,
                                      layout: :horizontal,
                                      charts: %i[
                                        electricity_by_day_of_week_simulator
                                        electricity_by_day_of_week_actual_for_simulator_comparison
                                      ]
                                    }
                                  },
                                  {
                                    type: :simulator_group_by_time_of_day_comparison,
                                    name: 'Comparison of Simulator and Actual Electricity Consumption by Time Of Day for the Last Year',
                                    advice_text: true,
                                    chart_group: {
                                      link_y_axis: true,
                                      layout: :horizontal,
                                      charts: %i[
                                        intraday_electricity_simulator_simulator_for_comparison
                                        intraday_electricity_simulator_actual_for_comparison
                                      ]
                                    }
                                  },
                                  :group_by_week_electricity_dd
                                ]
                              },
    simulator_detail:       {
                                name: 'Simulator - Appliance Breakdown',
                                charts: %i[
                                  electricity_simulator_pie_detail_page

                                  group_by_week_electricity_simulator_lighting
                                  intraday_electricity_simulator_lighting_kwh
                                  intraday_electricity_simulator_lighting_kw

                                  group_by_week_electricity_simulator_ict
                                  electricity_by_day_of_week_simulator_ict
                                  intraday_electricity_simulator_ict

                                  group_by_week_electricity_simulator_electrical_heating

                                  group_by_week_electricity_simulator_security_lighting
                                  intraday_electricity_simulator_security_lighting_kwh

                                  group_by_week_electricity_air_conditioning
                                  intraday_electricity_simulator_air_conditioning_kwh

                                  group_by_week_electricity_flood_lighting
                                  intraday_electricity_simulator_flood_lighting_kwh

                                  group_by_week_electricity_kitchen
                                  intraday_electricity_simulator_kitchen_kwh

                                  group_by_week_electricity_simulator_boiler_pump
                                  intraday_electricity_simulator_boiler_pump_kwh

                                  group_by_week_electricity_simulator_solar_pv
                                  intraday_electricity_simulator_solar_pv_kwh
                                ]
                              },
    simulator_debug:      {
                                name: 'Simulator - Appliance Breakdown',
                                charts: %i[
                                  intraday_line_school_days_6months_simulator
                                  intraday_line_school_days_6months
                                  intraday_line_school_days_6months_simulator_submeters

                                  intraday_electricity_simulator_actual_for_comparison
                                  intraday_electricity_simulator_simulator_for_comparison
                                ]
                              },
    heating_model_fitting: {
                                name: 'Heating Model Fitting',
                                change_measurement_units:   false,
                                charts: %i[
                                  group_by_week_gas_model_fitting_one_year
                                  group_by_week_gas_model_fitting_unlimited
                                  gas_by_day_of_week_model_fitting
                                  gas_longterm_trend_model_fitting
                                  thermostatic_regression_simple_school_day_non_heating_regression_covid_tolerant
                                  seasonal_simple_school_day_non_heating_regression_covid_tolerant
                                  thermostatic_regression_simple_school_day_non_heating_regression
                                  seasonal_simple_school_day_non_heating_regression
                                  thermostatic_regression_simple_school_day_non_heating_non_regression
                                  seasonal_simple_school_day_non_heating_non_regression
                                  thermostatic_regression_simple_school_day
                                  thermostatic_regression_simple_all
                                  thermostatic_regression_thermally_massive_school_day
                                  thermostatic_regression_thermally_massive_all
                                  cusum_weekly_best_model
                                  thermostatic_winter_holiday_best
                                  thermostatic_winter_weekend_best
                                  thermostatic_summer_school_day_holiday_best
                                  thermostatic_summer_weekend_best
                                  thermostatic_non_best
                                  cusum_simple
                                  cusum_thermal_mass
                                  heating_on_off_by_week
                                  thermostatic_model_categories_pie_chart
                                  heating_on_off_pie_chart
                                ],
                               }
}.freeze
end
