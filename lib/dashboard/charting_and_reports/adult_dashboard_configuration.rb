class DashboardConfiguration
  ADULT_DASHBOARD_GROUPS = {
    benchmark:      %i[benchmark],
    benchmark_kwh_electric_only: %i[benchmark_kwh_electric_only],
    electric_group: %i[
      electric_annual
      electric_out_of_hours
      baseload
      electric_long_term_progress
      electric_recent_progress
      electric_intraday
      solar_pv_group
      underlying_electricity_meters_breakdown
    ],
    gas_group: %i[
      gas_annual
      gas_out_of_hours
      gas_long_term_progress
      gas_recent_progress
      underlying_gas_meters_breakdown
    ],
    boiler_control_group: %i[
      boiler_control_morning_start_time
      boiler_control_seasonal
      boiler_control_thermostatic
      boiler_control_frost
    ],
    hotwater_group: %i[
      hotwater
    ],
    storage_heater_group: %i[
      storage_heater
    ],
    carbon_group: %i[
      carbon
    ],
  }.freeze

  ADULT_DASHBOARD_GROUP_CONFIGURATIONS = {
    benchmark: { 
      name:                   'How you school\'s energy consumption compares with other schools',
      content_class:          AdviceBenchmark,
      excel_worksheet_name:   'Benchmark',
      charts:                 %i[benchmark],
      promoted_variables: {
        AlertEnergyAnnualVersusBenchmark => {
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          last_year_kwh:                        :last_year_kwh,
          last_year_co2:                        :last_year_co2,
          summary:                              :summary
        },
        AlertGasAnnualVersusBenchmark         => { gas_rating: :rating, gas_last_year_£: :last_year_£ },
        AlertElectricityAnnualVersusBenchmark => { 
          electric_rating: :rating,
          electric_last_year_£: :last_year_£
        },
        AlertStorageHeaterAnnualVersusBenchmark => { 
          storage_heater_rating: :rating,
          storage_heater_last_year_£: :last_year_£
        }
      }
    },
    electric_annual: {   
      name:                   'Overview of annual electricity consumption',
      content_class:          AdviceElectricityAnnual,
      excel_worksheet_name:   'ElectricityAnnual',
      charts: %i[
        benchmark_electric_only_£
        group_by_week_electricity
        electricity_longterm_trend
        group_by_week_electricity_unlimited
        electricity_by_month_year_0_1
      ],
      promoted_variables: {
        AlertElectricityAnnualVersusBenchmark => { # need new electricity trend alert!
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          percent_difference:                   :percent_difference_from_average_per_pupil,
          percent_difference_adjective:         :percent_difference_adjective,
          simple_percent_difference_adjective:  :simple_percent_difference_adjective,
          summary:                              :summary
        }
      },
    },
    electric_out_of_hours: {   
      name:                   'Your electricity use out of school hours',
      content_class:           AdviceElectricityOutHours,
      excel_worksheet_name:   'ElectricOutOfHours',
      charts: %i[
        daytype_breakdown_electricity
        electricity_by_day_of_week
      ],
      promoted_variables: {
        AlertOutOfHoursElectricityUsage => {
          rating:                 :rating,
          out_of_hours_£:         :out_of_hours_£,
          out_of_hours_percent:   :out_of_hours_percent,
          summary:                :summary
        }
      },
    },
    baseload: {   
      name:                   'Your electricity baseload',
      content_class:           AdviceBaseload,
      excel_worksheet_name:   'Baseload',
      charts: %i[
        baseload_lastyear
        baseload
      ],
      promoted_variables: {
        AlertElectricityBaseloadVersusBenchmark => {
          rating:                             :rating,
          one_year_saving_versus_exemplar_£:  :one_year_saving_versus_exemplar_£,
          one_year_saving_versus_benchmark_£: :one_year_saving_versus_benchmark_£,
          average_baseload_last_year_kw:      :average_baseload_last_year_kw,
          exemplar_per_pupil_kw:              :exemplar_per_pupil_kw,
          benchmark_per_pupil_kw:             :benchmark_per_pupil_kw,
          summary:                            :summary
        }
      },
    },
    electric_long_term_progress:  {   
      name:                   'Electricity: long term',
      content_class:           AdviceElectricityLongTerm,
      excel_worksheet_name:   'ElectricLongTerm',
      charts: %i[
        electricity_longterm_trend
        group_by_week_electricity
        group_by_week_electricity_unlimited
        electricity_by_month_year_0_1
      ],
      promoted_variables: {
        AlertElectricityLongTermTrend => {
          rating:           :rating,
          year_change_£:    :year_change_£,
          prefix_1:         :prefix_1,
          prefix_2:         :prefix_2,
          summary:          :summary
        }
      },
    },
    electric_recent_progress: {   
      name:                   'Electricity: recent',
      content_class:           AdviceElectricityRecent,
      excel_worksheet_name:   'ElectricRecent',
      charts: %i[
        adult_dashboard_drilldown_last_2_weeks_electricity_comparison
        intraday_line_school_last7days
        baseload_lastyear
      ],
=begin
      promoted_variables: {
        AlertSchoolWeekComparisonElectricity => {
          rating:             :rating,
          difference_kwh:     :difference_kwh,
          difference_£:       :difference_£,
          difference_percent: :difference_percent,
          prefix_1:           :prefix_1,
          prefix_2:           :prefix_2,
          summary:            :summary
        }
      },
=end
    },
    electric_intraday: {
      name:                   'Electricity: intraday',
      content_class:           AdviceElectricityIntraday,
      excel_worksheet_name:   'ElectricIntraday',
      charts: %i[
        intraday_line_school_days
        intraday_line_holidays
        intraday_line_weekends
        intraday_line_school_days_last5weeks
        intraday_line_school_days_6months
        intraday_line_school_last7days
        baseload_lastyear
      ],
      promoted_variables: {
        AlertElectricityPeakKWVersusBenchmark => {
          rating:         :rating,
          average_school_day_last_year_kw: :average_school_day_last_year_kw
        }
      },
    },
    gas_annual: {   
      name:                   'Overview of annual gas consumption',
      content_class:          AdviceGasAnnual,
      excel_worksheet_name:   'GasAnnual',
      charts: %i[
        benchmark_gas_only_£
        group_by_week_gas
        gas_longterm_trend
        group_by_week_gas_unlimited
        gas_by_month_year_0_1
      ],
      promoted_variables: {
        AlertGasAnnualVersusBenchmark => { # need new gas trend alert!
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          percent_difference:                   :percent_difference_from_average_per_floor_area,
          percent_difference_adjective:         :percent_difference_adjective,
          simple_percent_difference_adjective:  :simple_percent_difference_adjective,
          summary:                              :summary
        }
      },
    },
    gas_out_of_hours: {   
      name:                   'Your gas use out of school hours',
      content_class:           AdviceGasOutHours,
      excel_worksheet_name:   'GasOutOfHours',
      charts: %i[
        daytype_breakdown_gas
        gas_by_day_of_week
      ],
      promoted_variables: {
        AlertOutOfHoursGasUsage => {
          rating:                 :rating,
          out_of_hours_£:         :out_of_hours_£,
          out_of_hours_percent:   :out_of_hours_percent,
          summary:                :summary
        }
      },
    },
    gas_long_term_progress:  {   
      name:                   'Gas: long term',
      content_class:           AdviceGasLongTerm,
      excel_worksheet_name:   'GasLongTerm',
      charts: %i[
        gas_longterm_trend
        group_by_week_gas
        group_by_week_gas_unlimited
        gas_by_month_year_0_1
      ],
      promoted_variables: {
        AlertGasLongTermTrend => {
          rating:           :rating,
          year_change_£:    :year_change_£,
          prefix_1:         :prefix_1,
          prefix_2:         :prefix_2,
          summary:          :summary
        }
      },
    },
    gas_recent_progress: {   
      name:                   'Gas: recent',
      content_class:           AdviceGasRecent,
      excel_worksheet_name:   'GasRecent',
      charts: %i[
        last_2_weeks_gas_comparison_temperature_compensated
        last_7_days_intraday_gas
        last_2_weeks_gas
        last_2_weeks_gas_degreedays
        last_4_weeks_gas_temperature_compensated
      ],
=begin
      promoted_variables: {
        AlertSchoolWeekComparisonGas => {
          rating:             :rating,
          difference_kwh:     :difference_kwh,
          difference_£:       :difference_£,
          difference_percent: :difference_percent,
          prefix_1:           :prefix_1,
          prefix_2:           :prefix_2,
          summary:            :summary
        }
      },
=end
    },
    gas_intraday: {
      name:                   'Gas: intraday',
      content_class:           AdviceGasIntraday,
      excel_worksheet_name:   'GasIntraday',
      charts: %i[
        gas_heating_season_intraday
        last_7_days_intraday_gas
      ],
      promoted_variables: {
      },
    },
    boiler_control_morning_start_time: {
      name:                   'Morning start time',
      content_class:           AdviceGasBoilerMorningStart,
      excel_worksheet_name:   'GasStartTime',
      charts: %i[
        gas_heating_season_intraday
        optimum_start
      ],
      promoted_variables: {
        AlertHeatingComingOnTooEarly => {
          rating:         :rating,
          one_year_optimum_start_saving_£: :one_year_optimum_start_saving_£
        }
      },
    },
    boiler_control_seasonal: {
      name:                   'Seasonal Control',
      content_class:           AdviceGasBoilerSeasonalControl,
      excel_worksheet_name:   'GasSeasonalControl',
      charts: %i[
        heating_on_off_by_week
      ],
      promoted_variables: {
        AlertHeatingOnSchoolDays => {
          rating:         :rating,
          one_year_saving_reduced_days_to_exemplar_£: :one_year_saving_reduced_days_to_exemplar_£
        }
      },
    },
    boiler_control_thermostatic: {
      name:                   'Thermostatic',
      content_class:           AdviceGasBoilerThermostatic,
      excel_worksheet_name:   'GasThermostatic',
      charts: %i[
        thermostatic
        thermostatic_control_large_diurnal_range
        cusum
      ],
      promoted_variables: {
        AlertThermostaticControl => {
          rating:         :rating,
        },
        AlertHeatingSensitivityAdvice => {
          annual_saving_1_C_change_£: :annual_saving_1_C_change_£
        }
      },
    },
    boiler_control_frost: {
      name:                   'Frost',
      content_class:           AdviceGasBoilerFrost,
      excel_worksheet_name:   'Frost',
      charts: %i[frost],
      promoted_variables: {
      },
    },
    hotwater: {
      name:                   'Hot water',
      content_class:           AdviceGasHotWater,
      excel_worksheet_name:   'GasHotWater',
      charts: %i[
        hotwater
      ],
      promoted_variables: {
        AlertHotWaterEfficiency => {
          rating:         :rating,
          average_one_year_saving_£: :average_one_year_saving_£
        }
      },
    },
    storage_heater: {
      name:                   'Storage Heaters',
      content_class:           AdviceStorageHeaters,
      excel_worksheet_name:   'StorageHeaters',
      charts: %i[
        benchmark_storage_heater_only_£
        storage_heater_group_by_week
        storage_heater_group_by_week_long_term
        storage_heater_by_day_of_week
        storage_heater_intraday_current_year
        storage_heater_intraday_current_year_kw
        intraday_line_school_last7days_storage_heaters
        heating_on_off_by_week_storage_heater
        storage_heater_thermostatic
      ],
      promoted_variables: {
      },
    },
    solar_pv_group: {
      name:                   'Solar PV',
      content_class:           AdviceSolarPV,
      excel_worksheet_name:   'SolarPVS',
      charts: %i[
        solar_pv_group_by_month
        solar_pv_last_7_days_by_submeter
      ]
    },
    underlying_electricity_meters_breakdown: {
      name:                   'Electricity Meter Breakdown',
      content_class:           AdviceElectricityMeterBreakdownBase,
      excel_worksheet_name:   'ElectricBDown',
      charts: %i[ group_by_week_electricity_meter_breakdown_one_year ]
    },
    underlying_gas_meters_breakdown: {
      name:                   'Gas Meter Breakdown',
      content_class:           AdviceGasMeterBreakdownBase,
      excel_worksheet_name:   'GasBDown',
      charts: %i[ group_by_week_gas_meter_breakdown_one_year ]
    },
    carbon: {
      name:                   'Carbon',
      content_class:           AdviceCarbon,
      excel_worksheet_name:   'CO2',
      charts: %i[
        benchmark_co2
        electricity_longterm_trend_kwh_with_carbon
        electricity_longterm_trend_carbon
        electricity_co2_last_year_weekly_with_co2_intensity
        electricity_co2_last_7_days_with_co2_intensity
        electricity_kwh_last_7_days_with_co2_intensity
        gas_longterm_trend_kwh_with_carbon
        group_by_week_carbon
      ],
      promoted_variables: {
      },
    },
    energy_tariffs: {
      name:                   'Energy Tariffs',
      content_class:           AdviceEnergyTariffs,
      excel_worksheet_name:   'Tariffs',
      charts: %i[
        peak_kw
      ],
      promoted_variables: {
        AlertDifferentialTariffOpportunity => {
          rating:         :rating,
          total_potential_savings_£: :total_potential_savings_£
        }
      },
    },
  }.freeze
end
