class DashboardConfiguration
  DASHBOARD_PAGE_GROUPS = {  # dashboard page groups: defined page, and charts on that page
    main_dashboard_electric:  {
                                name:   'Overview',
                                charts: %i[
                                  benchmark
                                  daytype_breakdown_electricity
                                  group_by_week_electricity
                                ]
                              },
    # Benchmark currently not working for Gas only
    main_dashboard_gas:  {
                                name:   'Main Dashboard',
                                charts: %i[
                                  benchmark
                                  daytype_breakdown_gas
                                  group_by_week_gas
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
                                  last_2_weeks_gas
                                  last_2_weeks_gas_degreedays
                                  last_2_weeks_gas_comparison_temperature_compensated
                                  last_4_weeks_gas_temperature_compensated
                                  last_7_days_intraday_gas
                                ]
                              },
    main_dashboard_electric_and_gas: {
                                name:   'Overview',
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
                                  heating_on_off_by_week
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
                              },
        test:                 {
                                name: 'Useful Charts for Testing',
                                charts: %i[
                                  group_by_week_gas_unlimited_meter_filter_debug
                                  group_by_week_electricity_unlimited_meter_filter_debug
                                  electricity_longterm_trend
                                  gas_longterm_trend
                                  irradiance_test
                                  gridcarbon_test
                                  cusum_weekly
                                ]
                              },
        heating_model_fitting: {
                                name: 'Heating Model Fitting',
                                charts: %i[
                                  group_by_week_gas_model_fitting_one_year
                                  group_by_week_gas_model_fitting_unlimited
                                  gas_by_day_of_week_model_fitting
                                  gas_longterm_trend_model_fitting
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
                               },
        storage_heaters:      {
                                  name: 'Storage Heaters',
                                  charts: %i[
                                    storage_heater_group_by_week
                                    storage_heater_group_by_week_long_term
                                    storage_heater_by_day_of_week
                                    storage_heater_intraday_current_year
                                    storage_heater_intraday_current_year_kw
                                    intraday_line_school_last7days_storage_heaters
                                    storage_heater_thermostatic
                                    heating_on_off_by_week_storage_heater
                                  ],
                              },
        solar_pv:             {
                                name: 'Solar PV',
                                charts: %i[
                                  solar_pv_group_by_week
                                  group_by_week_electricity
                                  solar_pv_group_by_week_by_submeter
                                ],
                              },
        carbon_emissions:   {
                                name: 'Carbon Emissions',
                                charts: %i[
                                  benchmark_co2
                                  group_by_week_carbon
                                  electricity_longterm_trend_kwh_with_carbon
                                  electricity_longterm_trend_carbon
                                  electricity_intraday_line_school_last7days_co2_commentary
                                  electricity_intraday_line_school_last7days_carbon
                                  gas_longterm_trend_kwh_with_carbon
                                  gas_longterm_trend_carbon
                                  last_2_weeks_carbon_emissions
                                ],
                              }
}.freeze

=begin
                                  thermostatic_regression_simple
                                  thermostatic_regression_thermal_mass
                                  thermostatic_regression_best
                                  thermostatic_none
                                  thermostatic_winter_occupied
                                  thermostatic_winter_weekend
                                  thermostatic_winter_holiday
                                  thermostatic_summer_occupied
                                  thermostatic_summer_weekend
                                  thermostatic_summer_holiday
                                  
                                  thermostatic_model_by_week
                                  heating_on_off_by_week
                                  group_by_week_gas
                                  cusum_weekly
=end
  DASHBOARD_FUEL_TYPES = { # 2 main dashboards: 1 for electric only schools, one for electric and gas schools
    electric_only:
                        %i[
                            main_dashboard_electric
                            electricity_detail
                        ],
    gas_only:
                        %i[
                            main_dashboard_gas
                            gas_detail
                            boiler_control
                        ],
    electric_and_gas:
                        %i[
                            main_dashboard_electric_and_gas
                            electricity_detail
                            gas_detail
                            boiler_control
                        ],
    electric_and_storage_heaters:
                        %i[
                            main_dashboard_electric
                            electricity_detail
                            storage_heaters
                        ],
    electric_and_gas_and_solar_pv:
                        %i[
                            main_dashboard_electric_and_gas
                            electricity_detail
                            gas_detail
                            boiler_control
                            solar_pv
                        ],
  }.freeze
end
