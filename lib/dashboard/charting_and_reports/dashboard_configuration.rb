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
                                ]
                              },
    simulator:                {
                                name:   'Simulator Test',
                                charts: %i[
                                  group_by_week_electricity_dd
                                  group_by_week_electricity_simulator_daytype
                                  group_by_week_electricity_simulator_appliance
                                  electricity_simulator_pie
                                  intraday_line_school_days_6months_simulator
                                  intraday_line_school_days_6months
                                  intraday_line_school_days_6months_simulator_submeters
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