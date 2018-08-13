class DashboardConfiguration
  DASHBOARD_PAGE_GROUPS = {  # dashboard page groups: defined page, and charts on that page
    main_dashboard_electric:  {
                                name:   'Main Dashboard',
                                charts: %i[
                                  benchmark
                                  daytype_breakdown_electricity
                                  group_by_week_electricity
                                ]
                              },
    electricity_detail:      {
                                name:   'Electricity Detail',
                                charts: %i[
                                  daytype_breakdown_electricity
                                  group_by_week_electricity
                                  group_by_week_electricity_unlimited
                                  electricity_longterm_trend
                                  electricity_by_day_of_week
                                  baseload
                                  electricity_by_month_year_0_1
                                  intraday_line_school_days
                                  intraday_line_holidays
                                  intraday_line_weekends
                                  intraday_line_school_days_last5weeks
                                  intraday_line_school_days_6months
                                  intraday_line_school_last7days
                                  baseload_lastyear
                                ]
                              },
    gas_detail:               {
                                name:   'Gas Detail',
                                charts: %i[
                                  daytype_breakdown_gas
                                  group_by_week_gas
                                  group_by_week_gas_unlimited
                                  gas_longterm_trend
                                  gas_by_day_of_week
                                  gas_heating_season_intraday
                                ]
                              },
    main_dashboard_electric_and_gas: {
                                name:   'Main Dashboard',
                                charts: %i[
                                  benchmark
                                  daytype_breakdown_electricity
                                  daytype_breakdown_gas
                                  group_by_week_electricity
                                  group_by_week_gas
                                ]
                              },
    boiler_control:           {
                                name: 'Advanced Boiler Control',
                                charts: %i[
                                  group_by_week_gas
                                  frost_1
                                  frost_2
                                  frost_3
                                  thermostatic
                                  cusum
                                  thermostatic_control_large_diurnal_range_1
                                  thermostatic_control_large_diurnal_range_2
                                  thermostatic_control_large_diurnal_range_3
                                  thermostatic_control_medium_diurnal_range
                                  optimum_start
                                  hotwater
                                ]
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
                              }               
  }.freeze

  DASHBOARD_FUEL_TYPES = { # 2 main dashboards: 1 for electric only schools, one for electric and gas schools
    electric_only:
                        %i[
                            main_dashboard_electric
                            electricity_detail
                        ],
    electric_and_gas:
                        %i[
                            main_dashboard_electric_and_gas
                            electricity_detail
                            gas_detail
                            boiler_control
                        ]
  }.freeze
end