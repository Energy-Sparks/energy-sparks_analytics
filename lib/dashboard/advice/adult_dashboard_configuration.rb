require_rel './*.rb'
require_rel './costs/*.rb'
require_rel './../alerts/*/*.rb'
require_rel './../alerts/*/*/*.rb'

class DashboardConfiguration
  ADULT_DASHBOARD_GROUPS = {
    benchmark:      %i[benchmark],
    benchmark_kwh_electric_only: %i[benchmark_kwh_electric_only],
    electric_group: %i[
      electric_annual
      electric_out_of_hours
      baseload
      electric_target
      electric_long_term_progress
      electric_recent_progress
      electric_intraday
      solar_pv_group
      underlying_electricity_meters_breakdown
      electricity_profit_loss
      refrigeration
    ],
    gas_group: %i[
      gas_annual
      gas_out_of_hours
      gas_long_term_progress
      gas_recent_progress
      gas_target
      underlying_gas_meters_breakdown
      gas_profit_loss
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
      storage_heater_target
    ],
    carbon_group: %i[
      carbon
    ],
  }.freeze

  ADULT_DASHBOARD_GROUP_CONFIGURATIONS = {
    benchmark: { 
      name:                   'How your school\'s energy consumption compares with other schools',
      content_class:          AdviceBenchmark,
      excel_worksheet_name:   'Benchmark',
      charts:                 %i[benchmark benchmark_varying_floor_area_pupils],
      promoted_variables: {
        AlertEnergyAnnualVersusBenchmark => {
          rating:                               :rating,
          # enough_data:                          :enough_data,
          last_year_£:                          :last_year_£,
          last_year_£current:                   :last_year_£current,
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
        benchmark_electric_only_£_varying_floor_area_pupils
        group_by_week_electricity
        electricity_longterm_trend
        group_by_week_electricity_unlimited
        electricity_by_month_year_0_1
        group_by_week_electricity_versus_benchmark
      ],
      # these charts are mixed
      unsupported_in_front_end_example_benchmark_exemplar_charts: %i[
        group_by_week_electricity_versus_benchmark_line
        group_by_week_electricity_versus_benchmark_line_on_y2
        electricity_by_day_of_week_tolerant_versus_benchmarks
      ],
      skip_chart_and_advice_if_fails: %i[electricity_by_month_year_0_1],
      promoted_variables: {
        AlertElectricityAnnualVersusBenchmark => { # need new electricity trend alert!
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          last_year_£current:                   :last_year_£current,
          percent_difference:                   :percent_difference_from_average_per_pupil,
          percent_difference_adjective:         :percent_difference_adjective,
          simple_percent_difference_adjective:  :simple_percent_difference_adjective,
          summary:                              :summary
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ group_by_week_electricity ],
        fuel_type:          :electricity
      }
    },
    electric_out_of_hours: {
      name:                   'Your electricity use out of school hours',
      content_class:           AdviceElectricityOutHours,
      excel_worksheet_name:   'ElectricOutOfHours',
      charts: %i[
        daytype_breakdown_electricity_tolerant
        electricity_by_day_of_week_tolerant
      ],
      promoted_variables: {
        AlertOutOfHoursElectricityUsage => {
          rating:                 :rating,
          out_of_hours_£:         :out_of_hours_£,
          out_of_hours_percent:   :out_of_hours_percent,
          summary:                :summary
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ electricity_by_day_of_week_tolerant ],
        fuel_type:          :electricity
      }
    },
    baseload: {
      name:                   'Your electricity baseload',
      content_class:           AdviceBaseload,
      excel_worksheet_name:   'Baseload',
      # these charts aren't automatically interpreted, but picked
      # out of this list by AdviceBaseload code:
      charts: %i[
        baseload_lastyear
        baseload
        baseload_versus_benchmarks
      ],
      promoted_variables: {
        AlertElectricityBaseloadVersusBenchmark => {
          rating:                             :rating,
          one_year_saving_versus_exemplar_£_local:  :one_year_saving_versus_exemplar_£,
          one_year_saving_versus_benchmark_£_local: :one_year_saving_versus_benchmark_£,
          average_baseload_last_year_kw:      :average_baseload_last_year_kw,
          exemplar_per_pupil_kw:              :exemplar_per_pupil_kw,
          benchmark_per_pupil_kw:             :benchmark_per_pupil_kw,
          summary:                            :summary
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ baseload_lastyear ],
        fuel_type:          :electricity
      }
    },
    refrigeration: {
      name:                   'Experimental refrigeration analysis',
      content_class:           AdviceRefrigeration,
      excel_worksheet_name:   'Fridge',
      charts: %i[
        baseload_lastyear
        baseload
      ],
      promoted_variables: {
        AlertSummerHolidayRefrigerationAnalysis => {
          rating:                 :rating,
          annualised_reduction_£: :annualised_reduction_£,
          holiday_reduction_£:    :holiday_reduction_£,
          reduction_kw:           :reduction_kw,
          reduction_rating:       :reduction_rating,
          turn_off_rating:        :turn_off_rating,
          summary:                :summary
        }
      },
    },
    electric_target: {
      name:                   'Setting and tracking targets for your electricity',
      content_class:           AdviceTargetsElectricity,
      excel_worksheet_name:   'TargetElectric',
      charts: %i[
      ],
      promoted_variables: {
        AlertElectricityTargetAnnual => {
          rating:                                   :rating,
          # relevance:                                :relevance,
          # enough_data:                              :enough_data,
          school_name:                              :school_name,
          previous_year_kwh:                        :previous_year_kwh,
          current_year_kwh:                         :current_year_kwh,
          current_year_target_kwh:                  :current_year_target_kwh,
          current_year_percent_of_target_absolute:  :current_year_percent_of_target_absolute,
          current_year_percent_of_target_adjective: :current_year_percent_of_target_adjective,
          current_year_percent_of_target:           :current_year_percent_of_target,
          current_year_target_£_to_date:            :current_year_target_£_to_date,
          current_year_£:                           :current_year_£,
          current_year_target_kwh_to_date:          :current_year_target_kwh_to_date,
          summary:                                  :summary
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
      skip_chart_and_advice_if_fails: %i[electricity_by_month_year_0_1],
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
        intraday_line_school_days_reduced_data
        intraday_line_school_days_reduced_data_versus_benchmarks
        intraday_line_holidays
        intraday_line_weekends
        intraday_line_school_last7days
        baseload_lastyear
      ],
      skip_chart_and_advice_if_fails: %i[intraday_line_school_days_6months],
      promoted_variables: {
        AlertElectricityPeakKWVersusBenchmark => {
          rating:         :rating,
          average_school_day_last_year_kw: :average_school_day_last_year_kw
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ intraday_line_school_days_reduced_data ],
        fuel_type:          :electricity
      }
    },
    electricity_profit_loss: {   
      name:                   'Electricity Costs',
      content_class:           AdviceElectricityCosts,
      excel_worksheet_name:   'ElectCosts',
      charts: %i[],
      promoted_variables: {}
    },
    gas_annual: {   
      name:                   'Overview of annual gas consumption',
      content_class:          AdviceGasAnnual,
      excel_worksheet_name:   'GasAnnual',
      charts: %i[
        benchmark_gas_only_£
        benchmark_gas_only_£_varying_floor_area_pupils
        group_by_week_gas
        gas_longterm_trend
        group_by_week_gas_unlimited
        gas_by_month_year_0_1
      ],
      skip_chart_and_advice_if_fails: %i[gas_by_month_year_0_1],
      promoted_variables: {
        AlertGasAnnualVersusBenchmark => { # need new gas trend alert!
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          last_year_£current:                   :last_year_£current,
          percent_difference:                   :percent_difference_from_average_per_floor_area,
          percent_difference_adjective:         :percent_difference_adjective,
          simple_percent_difference_adjective:  :simple_percent_difference_adjective,
          summary:                              :summary
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ group_by_week_gas ],
        fuel_type:          :gas
      } 
    },
    gas_out_of_hours: {   
      name:                   'Your gas use out of school hours',
      content_class:           AdviceGasOutHours,
      excel_worksheet_name:   'GasOutOfHours',
      charts: %i[
        daytype_breakdown_gas_tolerant
        gas_by_day_of_week_tolerant
        gas_heating_season_intraday
      ],
      promoted_variables: {
        AlertOutOfHoursGasUsage => {
          rating:                 :rating,
          out_of_hours_£:         :out_of_hours_£,
          out_of_hours_percent:   :out_of_hours_percent,
          summary:                :summary
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ gas_by_day_of_week_tolerant gas_heating_season_intraday ],
        fuel_type:          :gas
      } 
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
      skip_chart_and_advice_if_fails: %i[gas_by_month_year_0_1],
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
    gas_target: {   
      name:                   'Setting and tracking targets for your gas',
      content_class:           AdviceTargetsGas,
      excel_worksheet_name:   'TargetGas',
      charts: %i[
      ],
      promoted_variables: {
        AlertGasTargetAnnual => {
          rating:                                   :rating,
          previous_year_kwh:                        :previous_year_kwh,
          current_year_kwh:                         :current_year_kwh,
          current_year_target_kwh:                  :current_year_target_kwh,
          current_year_percent_of_target_absolute:  :current_year_percent_of_target_absolute,
          current_year_percent_of_target_adjective: :current_year_percent_of_target_adjective,
          current_year_percent_of_target:           :current_year_percent_of_target,
          current_year_target_£_to_date:            :current_year_target_£_to_date,
          current_year_£:                           :current_year_£,
          current_year_target_kwh_to_date:          :current_year_target_kwh_to_date,
          summary:                                  :summary
        }
      },
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
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ gas_heating_season_intraday last_7_days_intraday_gas ],
        fuel_type:          :gas
      }
    },
    gas_profit_loss: {   
      name:                   'Gas Costs',
      content_class:           AdviceGasCosts,
      excel_worksheet_name:   'GasCosts',
      charts: %i[],
      promoted_variables: {}
    },
    boiler_control_morning_start_time: {
      name:                   'Morning start time',
      content_class:           AdviceGasBoilerMorningStart,
      excel_worksheet_name:   'GasStartTime',
      charts: %i[
        gas_heating_season_intraday_up_to_1_year
        optimum_start
      ],
      promoted_variables: {
        AlertHeatingComingOnTooEarly => {
          rating:         :rating,
          one_year_optimum_start_saving_£: :one_year_optimum_start_saving_£
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: nil }, # permission for all users
        charts:             [ 
          :gas_heating_season_intraday_up_to_1_year,
          { type: :html,           method:  :boiler_start_time_analysis,                user_type: { user_role: :analytics } },
          { type: :chart_name,     content: :boiler_start_time,                         user_type: { user_role: :analytics } },
          { type: :chart_name,     content: :boiler_start_time_up_to_one_year,          user_type: { user_role: :analytics } },
          { type: :chart_name,     content: :boiler_start_time_up_to_one_year_no_frost, user_type: { user_role: :analytics } }
        ],
        fuel_type:          :gas
      }
    },
    boiler_control_seasonal: {
      name:                   'Seasonal Control',
      content_class:           AdviceGasBoilerSeasonalControl,
      excel_worksheet_name:   'GasSeasonalControl',
      charts: %i[
        heating_on_off_by_week
      ],
      promoted_variables: {
        AlertSeasonalHeatingSchoolDays => {
          rating:         :rating,
          one_year_saving_£: :one_year_saving_£
        }
      },
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ heating_on_off_by_week ],
        fuel_type:          :gas
      }
    },
    boiler_control_thermostatic: {
      name:                   'Thermostatic Control',
      content_class:           AdviceGasThermostaticControl,
      excel_worksheet_name:   'GasThermostatic',
      charts: %i[
        thermostatic_up_to_1_year
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
      meter_breakdown: {
        presentation_style: :flat, # :structured || :flat
        user_type:          { user_role: :analytics },
        charts:             %i[ thermostatic_up_to_1_year ],
        fuel_type:          :gas
      }
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
        benchmark_storage_heater_only_£_varying_floor_area_pupils
        storage_heater_group_by_week
        storage_heater_group_by_week_long_term
        storage_heater_by_day_of_week_tolerant
        storage_heater_intraday_current_year
        storage_heater_intraday_current_year_kw
        intraday_line_school_last7days_storage_heaters
        heating_on_off_by_week_storage_heater
        storage_heater_thermostatic
      ],
      promoted_variables: {
      },
    },
    storage_heater_target: {   
      name:                   'Setting and tracking targets for your storage heaters',
      content_class:           AdviceTargetsStorageHeaters,
      excel_worksheet_name:   'TargetStorageHeater',
      charts: %i[
      ],
      promoted_variables: {
        AlertStorageHeaterTargetAnnual => {
          rating:                                   :rating,
          previous_year_kwh:                        :previous_year_kwh,
          current_year_kwh:                         :current_year_kwh,
          current_year_target_kwh:                  :current_year_target_kwh,
          current_year_percent_of_target_absolute:  :current_year_percent_of_target_absolute,
          current_year_percent_of_target_adjective: :current_year_percent_of_target_adjective,
          current_year_percent_of_target:           :current_year_percent_of_target,
          current_year_target_£_to_date:            :current_year_target_£_to_date,
          current_year_£:                           :current_year_£,
          current_year_target_kwh_to_date:          :current_year_target_kwh_to_date,
          summary:                                  :summary
        }
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
        electricity_co2_last_year_weekly_with_co2_intensity_co2_only
        electricity_co2_last_7_days_with_co2_intensity
        electricity_kwh_last_7_days_with_co2_intensity
        gas_longterm_trend_kwh_with_carbon
        group_by_week_carbon
      ],
      promoted_variables: {
        AlertEnergyAnnualVersusBenchmark => {
          rating:                               :rating,
          last_year_£:                          :last_year_£,
          last_year_kwh:                        :last_year_kwh,
          last_year_co2:                        :last_year_co2,
          trees_co2:                            :trees_co2,
          summary:                              :summary
        },
      }
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
      }
    },
  }.freeze
end
