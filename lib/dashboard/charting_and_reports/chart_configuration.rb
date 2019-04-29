# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  STANDARD_CHART_CONFIGURATION = {
    #
    # chart confif parameters:
    # name:               As appears in title of chart; passed through back to output with addition data e.g. total kWh
    # series_breakdown:   :fuel || :daytype || :heatingon - so fuel auto splits into [gas, electricity]
    #                      daytype into holidays, weekends, schools in and out of hours
    #                      heatingon - heating and non heating days
    #                     ultimately the plan is to support a list of breaddowns
    # chart1_type:        bar || column || pie || scatter - gets passed through back to output
    # chart1_subtype:     generally not present, if present 'stacked' is its most common value
    # x_axis:             grouping of data on xaxis: :intraday :day :week :dayofweek :month :year :academicyear
    # timescale:          period overwhich data aggregated - assumes tie covering all available data if missing
    # yaxis_units:        :£ etc. TODO PG,23May2018) - complete documentation
    # data_types:         an array e.g. [:metereddata, :predictedheat] - assumes :metereddata if not present
    #
    benchmark:  {
      name:             'Annual Electricity and Gas Consumption Comparison with other schools in your region',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      x_axis:           :year,
      series_breakdown: :fuel,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      inject:           :benchmark
    },
    benchmark_co2: {
      inherits_from:    :benchmark,
      name:             'Your schools carbon emissions from electricity and gas over last few years',
      yaxis_units:      :co2
    },
    last_2_weeks_carbon_emissions: {
      name:             'Last 2 weeks carbon emissions at your school from electricity and gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      timescale:        { week: -1..0 },
      meter_definition: :all,
      x_axis:           :day,
      series_breakdown: :fuel,
      yaxis_units:      :co2,
      yaxis_scaling:    :none
    },
    benchmark_electric:  {
      name:             'Benchmark Comparison (Annual Electricity Consumption)',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      x_axis:           :year,
      series_breakdown: :fuel,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      inject:           :benchmark
      # timescale:        :year
    },
    gas_longterm_trend: {
      name:             'Gas: long term trends',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      reverse_xaxis:    true
    },
    gas_longterm_trend_kwh_with_carbon: {
      inherits_from:    :gas_longterm_trend,
      series_breakdown: :none,
      y2_axis:          :gascarbon
    },
    gas_longterm_trend_carbon: {
      inherits_from:    :gas_longterm_trend,
      series_breakdown: :none,
      yaxis_units:      :co2,
      y2_axis:          :gascarbon
    },
    electricity_longterm_trend: {
      name:             'Electricity: long term trends',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      reverse_xaxis:    true
    },
    electricity_longterm_trend_kwh_with_carbon: {
      inherits_from:    :electricity_longterm_trend,
      series_breakdown: :none,
      y2_axis:          :gridcarbon
    },
    electricity_longterm_trend_carbon: {
      inherits_from:    :electricity_longterm_trend,
      series_breakdown: :none,
      yaxis_units:      :co2,
      y2_axis:          :gridcarbon
    },
    daytype_breakdown_gas: {
      name:             'Breakdown by type of day/time: Gas',
      chart1_type:      :pie,
      meter_definition: :allheat,
      x_axis:           :nodatebuckets,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    daytype_breakdown_combined_fuels: {
      inherits_from:    :daytype_breakdown_gas,
      series_breakdown: %i[model_type temperature],
    },
    alert_daytype_breakdown_gas: {
      inherits_from: :daytype_breakdown_gas
    },
    daytype_breakdown_electricity: {
      name:             'Breakdown by type of day/time: Electricity',
      chart1_type:      :pie,
      meter_definition: :allelectricity,
      x_axis:           :nodatebuckets,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    alert_daytype_breakdown_electricity: {
      inherits_from: :daytype_breakdown_electricity
    },
    group_by_week_electricity: {
      name:             'By Week: Electricity',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    alert_group_by_week_electricity: {
      inherits_from:    :group_by_week_electricity,
      yaxis_units:      :£,
    },
    storage_heater_group_by_week: {
      name:               'Storage heater by week of the year',
      inherits_from:      :group_by_week_electricity,
      meter_definition:   :storage_heater_meter,
      y2_axis:            :degreedays
    },
    storage_heater_by_day_of_week: {
      name:               'Storage heater by day of the week (year to date)',
      inherits_from:      :gas_by_day_of_week,
      meter_definition:   :storage_heater_meter
    },
    storage_heater_group_by_week_long_term: {
      name:               'Storage heater by day of the week (all years)',
      inherits_from:      :storage_heater_group_by_week,
      timescale:          nil
    },
    storage_heater_thermostatic: {
      name:               'Storage heater thermostatic control by day of the week (year to date)',
      inherits_from:      :thermostatic,
      meter_definition:   :storage_heater_meter
    },
    storage_heater_intraday_current_year: {
      name:               'Storage heater intraday profile (kwh) for year to date',
      inherits_from:      :gas_heating_season_intraday,
      meter_definition:   :storage_heater_meter
    },
    storage_heater_intraday_current_year_kw: {
      name:               'Storage heater intraday profile (kw) for year to date',
      chart1_type:        :line,
      inherits_from:      :storage_heater_intraday_current_year,
      yaxis_units:        :kw
    },
    intraday_line_school_last7days_storage_heaters:  {
      inherits_from:    :intraday_line_school_last7days,
      name:             'Intraday (last 7 days) storage heaters',
      meter_definition: :storage_heater_meter
    },
    heating_on_off_by_week_storage_heater: {
      inherits_from:    :heating_on_off_by_week,
      name:             'Heating on/off periods',
      meter_definition: :storage_heater_meter
    },
    solar_pv_group_by_week: {
      name:               'Solar PV by week of the year',
      inherits_from:      :storage_heater_group_by_week,
      y2_axis:            :irradiance,
      meter_definition:   :solar_pv_meter
    },
    solar_pv_group_by_week_by_submeter: {
      name:               'Solar PV by week of the year',
      inherits_from:      :solar_pv_group_by_week,
      meter_definition: :allelectricity,
      series_breakdown:   :submeter
    },
    group_by_week_electricity_test_range: {
      inherits_from:    :group_by_week_electricity,
      name:             'By Day: Electricity Range Test',
      timescale:        {year: -3..-1}
    },
    electricity_by_day:  {
      inherits_from:    :group_by_week_electricity,
      name:             'By Day: Electricity',
      x_axis:           :day,
      timescale:        :week
    },
    electricity_by_datetime:  {
      inherits_from:    :group_by_week_electricity,
      name:             'By Time: Electricity',
      x_axis:           :datetime,
      timescale:        :day
    },
    electricity_by_datetime_line_kw:  {
      inherits_from:    :electricity_by_datetime,
      chart1_type:      :line,
      series_breakdown: :none,
      yaxis_units:      :kw
    },
    group_by_week_electricity_school_comparison: {
      inherits_from:    :group_by_week_electricity,
      name:             'By Week: Electricity - School Comparison',
      series_breakdown: :none,
      chart1_subtype:   nil,
      yaxis_scaling:    :per_floor_area,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    group_by_week_electricity_school_comparison_with_average: {
      inherits_from:    :group_by_week_electricity,
      name:             'By Week: Electricity - School Comparison',
      series_breakdown: :none,
      chart1_subtype:   nil,
      yaxis_scaling:    :per_floor_area,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 },  # Castle
        :average
      ]
    },
    benchmark_school_comparison: {
      name:             'Benchmark - School Comparison - Annual Electricity and Gas',
      inherits_from:    :benchmark,
      yaxis_scaling:    :per_floor_area,
      chart1_subtype:   nil,
      sort_by:          [ { school: :asc }, { time: :asc } ],
      group_by:         [:fuel, :school],
      # timescale:        :year,
# inject:           nil,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    group_by_week_electricity_school_comparison_line: {
      inherits_from:    :group_by_week_electricity_school_comparison,
      chart1_type:      :line
    },
    electricity_longterm_trend_school_comparison: {
      inherits_from:    :electricity_longterm_trend,
      name:             'Electricity: long term trends school comparison',
      series_breakdown: :none,
      chart1_subtype:   nil,
      yaxis_scaling:    :per_floor_area,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    intraday_line_school_days_school_comparison: {
      inherits_from:    :intraday_line_school_days,
      name:             'Electricity: comparison of last 2 years and school comparison',
      series_breakdown: :none,
      yaxis_scaling:    :per_200_pupils,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    group_by_week_electricity_unlimited: {
      name:             'By Week: Electricity (multi-year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      zoomable:         true,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    group_by_week_electricity_unlimited_meter_filter_debug: {
      name:             'By Week: Electricity (Meter Breakdown)',
      meter_definition: :allelectricity,
      inherits_from:    :group_by_week_gas_unlimited_meter_filter_debug,
      series_breakdown: :meter
    },
    group_by_week_gas: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      timescale:        :year
    },
    alert_group_by_week_gas: {
      inherits_from:    :group_by_week_gas,
      yaxis_units:      :£
    },
    group_by_week_carbon: {
      name:             'Carbon emissions from gas heating, hot water and kitchen usage over the last year',
      inherits_from:    :group_by_week_gas,
      series_breakdown: :none,
      yaxis_units:      :co2
    },
    group_by_week_gas_unlimited: {
      name:             'By Week: Gas (multi-year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      zoomable:         true,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_unlimited_meter_filter_debug: {
      name:             'By Week: Gas (Meter Breakdown)',
      inherits_from:    :group_by_week_gas_unlimited,
      series_breakdown: :meter
      # filter:            { meter: [ 'Electrical Heating' ] } 
    },
    group_by_year_gas_unlimited_meter_breakdown_heating_model_fitter: {
      name:             'Gas meter breakdown by year',
      inherits_from:    :group_by_week_gas_unlimited,
      x_axis:           :year,
      series_breakdown: :meter
    },
    group_by_week_gas_kw: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh_pupil: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :per_pupil,
      y2_axis:          :degreedays
    },
    group_by_week_gas_co2_floor_area: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :co2,
      yaxis_scaling:    :per_floor_area,
      y2_axis:          :degreedays
    },
    group_by_week_gas_library_books: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :library_books,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    gas_latest_years:  {
      name:             'Gas Use Over Last Few Years (to date)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    gas_latest_academic_years:  {
      name:             'Gas Use Over Last Few Academic Years',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :academicyear,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    gas_by_day_of_week:  {
      name:             'Gas Use By Day of the Week (this year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_day_of_week:  {
      name:             'Electricity Use By Day of the Week (this year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_month_acyear_0_1:  {
      name:             'Electricity Use By Month (previous 2 academic years)',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      series_breakdown: :none,
      x_axis:           :month,
      timescale:        [{ academicyear: 0 }, { academicyear: -1 }],
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_month_year_0_1:  {
      name:             'Electricity Use By Month (last 2 years)',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      series_breakdown: :none,
      x_axis:           :month,
      timescale:        [{ year: 0 }, { year: -1 }],
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_cost_comparison_last_2_years: {
      inherits_from:    :electricity_by_month_year_0_1,
      yaxis_units:      :£
    },
    electricity_cost_comparison_last_2_years_accounting: {
      inherits_from:    :electricity_cost_comparison_last_2_years,
      yaxis_units:      :accounting_cost
    },
    electricity_cost_comparison_last_2_years_accounting_breakdown: {
      name:             'Electricity accounting cost by month for the last year',
      inherits_from:    :electricity_cost_comparison_last_2_years_accounting,
      series_breakdown: :accounting_cost
    },
    electricity_cost_1_year_accounting_breakdown: {
      name:             'Electricity accounting cost breakdown by month for the last year (stacked)',
      inherits_from:    :electricity_cost_comparison_last_2_years_accounting_breakdown,
      chart1_subtype:   :stacked,
      timescale:        :year
    },
    electricity_cost_comparison_1_year_accounting_breakdown_by_week: {
      name:             'Electricity accounting cost breakdown by week for the last year',
      inherits_from:    :electricity_cost_1_year_accounting_breakdown,
      x_axis:           :week
    },
    gas_cost_comparison_1_year_accounting_breakdown_by_week: {
      name:             'Gas accounting cost breakdown by week for the last year',
      meter_definition: :allheat,
      inherits_from:    :electricity_cost_1_year_accounting_breakdown,
      x_axis:           :week,
      y2_axis:          :degreedays
    },
    gas_cost_comparison_1_year_economic_breakdown_by_week: {
      name:             'Gas economic cost breakdown by week for the last year',
      inherits_from:    :gas_cost_comparison_1_year_accounting_breakdown_by_week,
      series_breakdown: :none,
      yaxis_units:      :£,
      x_axis:           :week
    },
    electricity_2_week_accounting_breakdown: {
      name:             'Electricity accounting cost breakdown by day for last 2 weeks',
      inherits_from:    :electricity_cost_comparison_1_year_accounting_breakdown_by_week,
      timescale:        [{ day: -13...0 }],
      x_axis:           :day
    },
    electricity_1_year_intraday_accounting_breakdown: {
      name:             'Electricity costs for last year by time of day (accounting costs)',
      inherits_from:    :gas_heating_season_intraday,
      meter_definition: :allelectricity,
      filter:           nil,
      series_breakdown: :accounting_cost,
      yaxis_units:      :£,
      chart1_subtype:   :stacked
    },
    electricity_1_year_intraday_kwh_breakdown: {
      name:             'Electricity kWh usage intraday for last year for comparison with accounting version above',
      inherits_from:    :electricity_1_year_intraday_accounting_breakdown,
      series_breakdown: :none,
      yaxis_units:      :kwh
    },
    gas_1_year_intraday_accounting_breakdown: {
      name:             'Gas costs for last year by time of day (accounting costs)',
      inherits_from:    :electricity_1_year_intraday_accounting_breakdown,
      meter_definition: :allheat
    },
    gas_1_year_intraday_economic_breakdown: {
      name:             'Gas costs for last year by time of day (economic costs)',
      series_breakdown: :none,
      inherits_from:    :gas_1_year_intraday_accounting_breakdown,
      yaxis_units:      :£
    },
    gas_1_year_intraday_kwh_breakdown: {
      name:             'Gas kWh usage intraday for last year for comparison with accounting version above',
      inherits_from:    :gas_1_year_intraday_accounting_breakdown,
      series_breakdown: :none,
      yaxis_units:      :kwh
    },
    gas_heating_season_intraday: {
      name:             'Intraday Gas Consumption (during heating season)',
      chart1_type:      :column,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: true },
      series_breakdown: :none,
      x_axis:           :intraday,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    gas_heating_season_intraday_£: { # temporary chart 18Mar19 to bug fix non £ scaling intradat kWh charts
      inherits_from: :gas_heating_season_intraday,
      yaxis_units: :£
    },
    alert_gas_heating_season_intraday: {
      inherits_from: :gas_heating_season_intraday,
      yaxis_units: :£
    },
    gas_intraday_schoolday_last_year: { # used by heating regression fitter
      name:             'Intra-school day gas consumption profile',
      inherits_from:    :gas_heating_season_intraday,
      series_breakdown: :none,
      filter:           { daytype: :occupied }
    },
    meter_breakdown_pie_1_year: { # used by heating regression fitter
      name:             'Breakdown by meter (this year): Gas',
      inherits_from:    :daytype_breakdown_gas,
      x_axis:           :nodatebuckets,
      series_breakdown: :meter
    },
    group_by_week_gas_model_fitting_one_year: { # aliased for different advice
      name:             'By Week: Gas (1 year)',
      inherits_from:    :group_by_week_gas_unlimited,
      timescale:        :year
    },
    group_by_week_gas_model_fitting_unlimited: { # aliased for different advice
      name:             'By Week: Gas (all data)',
      inherits_from:    :group_by_week_gas_unlimited
    },
    gas_by_day_of_week_model_fitting: {
      inherits_from:    :gas_by_day_of_week
    },
    gas_longterm_trend_model_fitting: {
      inherits_from:    :gas_longterm_trend
    },
    thermostatic_regression: {
      name:             'Thermostatic (Regression_Model Testing)',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      series_breakdown: %i[model_type temperature],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    thermostatic_regression_simple_school_day: {
      name:             'Thermostatic (School Day) - simple model',
      inherits_from:    :thermostatic_regression,
      series_breakdown: %i[model_type temperature],
      trendlines:       %i[heating_occupied_all_days summer_occupied_all_days],
      filter:           { model_type: %i[heating_occupied_all_days summer_occupied_all_days] },
      model:            :simple_regression_temperature
    },
    thermostatic: {
      inherits_from:    :thermostatic_regression_simple_school_day,
      name:             'Thermostatic (Temperature v. Daily Consumption - current year)',
    },
    thermostatic_regression_simple_all: {
      name:             'Thermostatic (All Categories) - simple model',
      inherits_from:    :thermostatic_regression,
      model:            :simple_regression_temperature,
      trendlines:       %i[
                          heating_occupied_all_days
                          weekend_heating
                          holiday_heating
                          summer_occupied_all_days
                          holiday_hotwater_only
                          weekend_hotwater_only
                        ],
    },
    thermostatic_regression_thermally_massive_school_day: {
      name:             'Thermostatic (School Day) - thermally massive model',
      inherits_from:    :thermostatic_regression_simple_school_day,
      model:            :thermal_mass_regression_temperature
    },
    thermostatic_regression_thermally_massive_all: {
      name:             'Thermostatic (All Categories) - thermally massive model',
      inherits_from:    :thermostatic_regression_simple_all,
      model:            :thermal_mass_regression_temperature,
      trendlines:       %i[
        heating_occupied_monday
        heating_occupied_tuesday
        heating_occupied_wednesday
        heating_occupied_thursday
        heating_occupied_friday
        weekend_heating
        holiday_heating
        summer_occupied_all_days
        holiday_hotwater_only
        weekend_hotwater_only
      ],
    },
    cusum_weekly_best_model: {
      inherits_from:    :cusum_weekly,
      model:            :best,
      timescale:        nil
    },
    thermostatic_winter_holiday_best: {
      name:             'Thermostatic (Winter Holiday)',
      inherits_from:    :thermostatic_regression,
      model:            :best,
      filter:           { model_type: :holiday_heating },
      trendlines:       %i[ holiday_heating ]
    },
    thermostatic_winter_weekend_best: {
      name:             'Thermostatic (Winter Weekend)',
      inherits_from:    :thermostatic_winter_holiday_best,
      filter:           { model_type: :weekend_heating },
      trendlines:       %i[ weekend_heating ]
    },
    thermostatic_summer_school_day_holiday_best: {
      name:             'Thermostatic (Summer Weekend and Holiday)',
      inherits_from:    :thermostatic_winter_holiday_best,
      filter:           { model_type: %i[summer_occupied_all_days holiday_hotwater_only] },
      trendlines:       %i[ summer_occupied_all_days holiday_hotwater_only ]
    },
    thermostatic_summer_weekend_best: {
      name:             'Thermostatic (Summer Weekend and Holiday)',
      inherits_from:    :thermostatic_winter_holiday_best,
      filter:           { model_type: :weekend_hotwater_only },
      trendlines:       %i[ weekend_hotwater_only ]
    },
    thermostatic_non_best: {
      name:             'Thermostatic (Days of minimal consumption)',
      inherits_from:    :thermostatic_winter_holiday_best,
      filter:           { model_type: :none }
    },
    cusum_simple: {
      name:             'CUSUM: simple model',
      inherits_from:    :cusum,
      model:            :simple_regression_temperature
    },
    cusum_thermal_mass: {
      name:             'CUSUM: thermal mass model model',
      inherits_from:    :cusum_simple,
      model:            :thermal_mass_regression_temperature
    },
    thermostatic_model_by_week: {
      name:             'Thermostatic model type by week',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :model_type,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    heating_on_off_by_week: {
      name:             'Heating season analysis',
      inherits_from:    :thermostatic_model_by_week,
      timescale:        :year,
      model:            :best,
      series_breakdown: :heating
    },
    thermostatic_model_categories_pie_chart: {
      name:             'Categorised consumption by model',
      inherits_from:    :thermostatic_model_by_week,
      model:            :best,
      chart1_type:      :pie,
      chart1_subtype:   nil,
      y2_chart_type:    nil,
      y2_axis:          nil,
      x_axis:           :nodatebuckets
    },
    heating_on_off_pie_chart: {
      name:             'Heating versus non-heating day gas consumption',
      inherits_from:    :heating_on_off_by_week,
      model:            :best,
      chart1_type:      :pie,
      chart1_subtype:   nil,
      y2_chart_type:    nil,
      y2_axis:          nil,
      x_axis:           :nodatebuckets
    },
=begin
    thermostatic_regression_simple: {
      name:             'Thermostatic (Winter - School Day) - simple model',
      inherits_from:    :thermostatic_regression,
      model:            :simple_regression_temperature
    },
    thermostatic_regression_thermal_mass: {
      name:             'Thermostatic (Winter - School Day) - thermal mass model',
      inherits_from:    :thermostatic_regression,
      model:            :thermal_mass_regression_temperature
    },
    thermostatic_regression_best: {
      name:             'Thermostatic (Winter - School Day) - best model',
      inherits_from:    :thermostatic_regression,
      model:            :best
    },
    thermostatic_winter_occupied: {
      name:             'Thermostatic (Winter - School Day)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: %i[heating_occupied_all_days heating_occupied_monday heating_occupied_tuesday heating_occupied_wednesday heating_occupied_thursday heating_occupied_friday] }
    },
    thermostatic_winter_weekend: {
      name:             'Thermostatic (Winter Weekend)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: :weekend_heating }
    },
    thermostatic_summer_occupied: {
      name:             'Thermostatic (Summer - School Days)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: :summer_occupied_all_days }
    },
    thermostatic_summer_weekend: {
      name:             'Thermostatic (Summer Weekend)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: :weekend_hotwater_only }
    },
    thermostatic_summer_holiday: {
      name:             'Thermostatic (Summer Holiday)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: :holiday_hotwater_only }
    },
    thermostatic_none: {
      name:             'Thermostatic (Not heating or hot water)',
      inherits_from:    :thermostatic_regression,
      filter:           { model_type: :none }
    },
=end
    thermostatic_non_heating: {
      name:             'Thermostatic (Non Heating Season, School Day)',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: false },
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    cusum_weekly: {
      name:             'Weekly CUSUM - divergence from modelled gas consumption',
      chart1_type:      :column,
      meter_definition: :allheat,
      series_breakdown: :cusum,
      timescale:        :year,
      x_axis:           :week,
      y2_axis:          :degreedays,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    cusum: {
      inherits_from:    :cusum_weekly
=begin
      name:             'CUSUM',
      chart1_type:      :column,
      meter_definition: :allheat,
      series_breakdown: :cusum,
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
=end
    },
    baseload: {
      name:             'Baseload kW',
      chart1_type:      :line,
      series_breakdown: :baseload,
      meter_definition: :allelectricity,
      x_axis:           :day,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    baseload_lastyear: {
      name:             'Baseload kW - last year',
      chart1_type:      :line,
      series_breakdown: :baseload,
      meter_definition: :allelectricity,
      timescale:        :year,
      x_axis:           :day,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    alert_1_year_baseload: {
      inherits_from:    :baseload_lastyear,
    },
    intraday_line_school_days:  {
      name:             'Intraday (school days) - comparison of last 2 years',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_last5weeks:  {
      name:             'Intraday (Last 5 weeks comparison - school day)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -1 }, { schoolweek: -2 }, { schoolweek: -3 }, { schoolweek: -4 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months:  {
      name:             'Intraday (Comparison 6 months apart)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months_test_delete:  {
      name:             'Intraday (Comparison 6 months apart)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_last7days:  {
      name:             'Intraday (last 7 days)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ day: 0 }, { day: -1 }, { day: -2 }, { day: -3 }, { day: -4 }, { day: -5 }, { day: -6 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    electricity_intraday_line_school_last7days_co2_commentary: {
      inherits_from: :intraday_line_school_last7days
    },
    electricity_intraday_line_school_last7days_carbon: {
      inherits_from:    :intraday_line_school_last7days,
      yaxis_units:      :co2,
      y2_axis:          :gridcarbon
    },
    intraday_line_holidays:  {
      name:             'Intraday (holidays)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:           { daytype: :holidays },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_weekends:  {
      name:             'Intraday (weekends)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:           { daytype: :weekends },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    group_by_week_electricity_dd: {
      name:             'By Week: Electricity',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      timescale:        :year
    },
    group_by_week_electricity_simulator_appliance: {
      name:             'By Week: Electricity Simulator',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :electricity_simulator,
      x_axis:           :week,
      series_breakdown: :submeter,
      filter:            { submeter: [ 'Flood Lighting'] },
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    group_by_week_electricity_simulator_ict: {
      name:             'By Week: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },

    group_by_week_electricity_simulator_electrical_heating: {
      name:             'By Week: Electricity Simulator (Heating using Electricity)',
      inherits_from:    :group_by_week_gas,
      meter_definition: :electricity_simulator,
      series_breakdown: :submeter,
      filter:            { submeter: [ 'Electrical Heating' ] }
    },
    intraday_electricity_simulator_actual_for_comparison: {
      name:             'Annual: School Day by Time of Day (Actual)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :none,
      timescale:        :year,
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    intraday_electricity_simulator_simulator_for_comparison: {
      name:             'Annual: School Day by Time of Day (Simulator)',
      inherits_from:    :intraday_electricity_simulator_actual_for_comparison,
      meter_definition: :electricity_simulator
    },
    intraday_electricity_simulator_ict: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :intraday_electricity_simulator_actual_for_comparison,
      series_breakdown: :submeter,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied, submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },
    electricity_by_day_of_week_simulator_ict: {
      name:             'Annual: Usage by Day of Week: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :electricity_by_day_of_week_simulator,
      series_breakdown: :submeter,
      meter_definition: :electricity_simulator,
      filter:            { submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },

    #==============================SIMULATOR LIGHTING DETAIL==============================
    group_by_week_electricity_simulator_lighting: {
      name:             'By Week: Electricity Simulator (Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: [ 'Lighting' ] }
    },
    intraday_electricity_simulator_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { daytype: :occupied, submeter: ['Lighting'] }
    },
    intraday_electricity_simulator_lighting_kw: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Lighting)',
      inherits_from:    :intraday_electricity_simulator_lighting_kwh,
      yaxis_units:      :kw,
      filter:            { daytype: :occupied, submeter: ['Lighting'] }
    },
    #==============================SIMUALATOR BOILER PUMP DETAIL==============================
    group_by_week_electricity_simulator_boiler_pump: {
      name:             'By Week: Electricity Simulator (Boiler Pumps)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Boiler Pumps'] }
    },
    intraday_electricity_simulator_boiler_pump_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Boiler Pumps)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Boiler Pumps'] }
    },
    #==============================SIMUALATOR SECURITY LIGHTING DETAIL==============================
    group_by_week_electricity_simulator_security_lighting: {
      name:             'By Week: Electricity Simulator (Security Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Security Lighting'] }
    },
    intraday_electricity_simulator_security_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Security Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Security Lighting'] }
    },
    #==============================AIR CONDITIONING================================================
    group_by_week_electricity_air_conditioning: {
      name:             'By Week: Electricity Simulator (Air Conditioning)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Air Conditioning'] },
      y2_axis:          :temperature
    },
    intraday_electricity_simulator_air_conditioning_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Air Conditioning)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: [ 'Air Conditioning' ] }
    },
    #==============================FLOOD LIGHTING================================================
    group_by_week_electricity_flood_lighting: {
      name:             'By Week: Electricity Simulator (Flood Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Flood Lighting'] },
    },
    intraday_electricity_simulator_flood_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Flood Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Flood Lighting'] }
    },
    #==============================KITCHEN================================================
    group_by_week_electricity_kitchen: {
      name:             'By Week: Electricity Simulator (Kitchen)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Kitchen'] },
    },
    intraday_electricity_simulator_kitchen_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Kitchen)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Kitchen'] }
    },
    #==============================SOLAR PV================================================
    group_by_week_electricity_simulator_solar_pv: {
      name:             'By Month: Electricity Simulator (Solar PV)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      x_axis:           :month,
      filter:            { submeter: ['Solar PV Internal Consumption', 'Solar PV Export'] }
    },
    intraday_electricity_simulator_solar_pv_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Solar PV)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Solar PV Internal Consumption', 'Solar PV Export'] }
    },

    # MAIN SIMULATOR DASHBOARD CHARTS
    electricity_simulator_pie: {
      name:             'Electricity Simulator (Simulated Usage Breakdown Over the Last Year)',
      chart1_type:      :pie,
      meter_definition: :electricity_simulator,
      x_axis:           :nodatebuckets,
      series_breakdown: :submeter,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    electricity_simulator_pie_detail_page: {
      inherits_from:    :electricity_simulator_pie,
    },

    group_by_week_electricity_actual_for_simulator_comparison: {
      name:             'By Week: Electricity (Actual Usage)',
      inherits_from:    :group_by_week_electricity
    },
    group_by_week_electricity_simulator: {
      name:             'By Week: Electricity (Simulator)',
      inherits_from:    :group_by_week_electricity_actual_for_simulator_comparison,
      meter_definition: :electricity_simulator
    },
    electricity_by_day_of_week_actual_for_simulator_comparison:  {
      name:             'Electricity Use By Day of the Week (Actual Usage over last year)',
      inherits_from:    :electricity_by_day_of_week,
    },
    electricity_by_day_of_week_simulator:  {
      name:             'Electricity Use By Day of the Week (Simulator Usage over last year)',
      inherits_from:    :electricity_by_day_of_week,
      meter_definition: :electricity_simulator
    },

    intraday_line_school_days_6months_simulator:  {
      name:             'Intraday (Comparison 6 months apart) Simulator',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months_simulator_submeters:  {
      name:             'Intraday (Comparison 6 months apart) Simulator',
      chart1_type:      :line,
      series_breakdown: :submeter,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    frost_1:  {
      name:             'Frost Protection Example Sunday 1',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: 0 }], # 1 day either side of frosty day i.e. 3 days
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    frost_2:  {
      name:             'Frost Protection Example Sunday 2',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: -1 }], # skip -1 for moment, as 12-2-2017 has no gas data at most schools TODO(PH,27Jun2017) - fix gas data algorithm
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    frost_3:  {
      name:             'Frost Protection Example Sunday 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: -2 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_1:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 1',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: 0 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_2:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 2',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -1 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_3:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -2 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_medium_diurnal_range:  {
      name:             'Thermostatic Control Medium Diurnal Range Assessment 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -20 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    optimum_start:  {
      name:             'Optimum Start Control Check',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ optimum_start: 0}, { optimum_start: -1 } ], # fixed dates: one relatively mild, one relatively cold
      x_axis:           :intraday,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    hotwater: {
      name:             'Hot Water Analysis',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :hotwater,
      x_axis:           :day,
      meter_definition: :allheat,
      yaxis_units:      :kwh
    },
    hotwater_alert: {
      inherits_from:    :hotwater,
      yaxis_units:      :£
    },
    irradiance_test:  {
      name:             'Solar Irradiance Y2 axis check',
      inherits_from:    :optimum_start,
      y2_axis:          :irradiance
    },
    gridcarbon_test:  {
      name:             'Grid Carbon Y2 axis check',
      inherits_from:    :optimum_start,
      y2_axis:          :gridcarbon
    },
    last_2_weeks_gas_comparison: {
      name:             'Comparison of last 2 weeks gas consumption',
      chart1_type:      :column,
      series_breakdown: :none,
      x_axis_reformat:  { date: '%A' },
      timescale:        [{ schoolweek: 0 }, { schoolweek: -1 }],
      x_axis:           :day,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    last_2_weeks_gas: {
      name:             'Last 2 weeks gas consumption (with temperature)',
      timescale:        { week: -1..0 },
      x_axis_reformat:  nil,
      inherits_from:    :last_2_weeks_gas_comparison
    },
    last_2_weeks_gas_degreedays: {
      name:             'Last 2 weeks gas consumption (with degree days)',
      y2_axis:          :degreedays,
      timescale:        { week: -1..0 },
      x_axis_reformat:  nil,
      inherits_from:    :last_2_weeks_gas
    },
    last_2_weeks_gas_comparison_temperature_compensated: {
      name:             'Comparison of last 2 weeks gas consumption - adjusted for outside temperature',
      adjust_by_temperature:  10.0,
      y2_axis:          nil,
      inherits_from:    :last_2_weeks_gas_comparison
    },
    teachers_landing_page_gas: {
      timescale:        { week: -1..0 }, 
      yaxis_units:      :£,
      inherits_from:    :last_2_weeks_gas_comparison_temperature_compensated
    },
    alert_last_2_weeks_gas_comparison_temperature_compensated: {
      inherits_from:    :last_2_weeks_gas_comparison_temperature_compensated
    },
    teachers_landing_page_electricity: {
      name:             'Comparison of last 2 weeks electricity consumption',
      meter_definition: :allelectricity,
      inherits_from:    :teachers_landing_page_gas
    },
    alert_week_on_week_electricity_daily_electricity_comparison_chart: {
      # used by short term change alert
      inherits_from:    :teachers_landing_page_electricity
    },
    alert_intraday_line_school_days_last5weeks: {
      inherits_from:    :intraday_line_school_days_last5weeks
    },
    alert_intraday_line_school_last7days: {
      inherits_from:    :intraday_line_school_days_last5weeks
    },
    last_4_weeks_gas_temperature_compensated: {
      name:             'Last 4 weeks gas consumption - adjusted for outside temperature',
      adjust_by_temperature:  10.0,
      timescale:        [{ day: -27...0 }],
      y2_axis:          nil,
      x_axis_reformat:  nil,
      inherits_from:    :last_2_weeks_gas_comparison
    },
    last_7_days_intraday_gas:  {
      inherits_from:    :intraday_line_school_last7days,
      name:             'Intraday (last 7 days) gas',
      meter_definition: :allheat
    },
    alert_last_7_days_intraday_gas_heating_on_too_early: {
      inherits_from:    :last_7_days_intraday_gas
    },
=begin
    last_2_weeks_gas_comparison_datetime: {
      name:             'Last 2 weeks gas consumption week',
      x_axis:           :datetime,
      chart1_type:      :line,
      inherits_from:    :last_2_weeks_gas_comparison
    },
    last_2_weeks_gas_datetime: {
      name:             'Last 2 weeks gas consumption week',
      x_axis:           :datetime,
      chart1_type:      :line,
      inherits_from:    :last_2_weeks_gas
    },
    last_2_weeks_gas_temperature_compensated: {
      name:             'Last 2 weeks gas consumption - adjusted for outside temperature',
      timescale:        { week: -1..0 },
      inherits_from:    :last_2_weeks_gas_comparison_temperature_compensated
    },
    last_8_weeks_gas_comparison: {
      name:             'Comparison of 2 months gas consumption',
      x_axis:           :day,
      timescale:        [{ week: -4..0 }, { week: -9..-5 }],
      inherits_from:    :last_2_weeks_gas_comparison
    },
    last_8_weeks_gas_comparison_temperature_compensated: {
      name:             'Comparison of last 2 months gas consumption - adjusted for outside temperature',
      timescale:        [{ week: -4..0 }, { week: -9..-5 }],
      x_axis:           :day,
      y2_axis:          nil,
      inherits_from:    :last_2_weeks_gas_comparison_temperature_compensated
    },
    last_8_weeks_gas_comparison_temperature_compensated_line: {
      name:             'Comparison of last 2 months gas consumption - adjusted for outside temperature',
      chart1_type:      :line,
      inherits_from:    :last_8_weeks_gas_comparison_temperature_compensated
    },
    last_28_days_gas_comparison_temperature_compensated_line: {
      name:             'Comparison of last 2 months gas consumption - adjusted for outside temperature',
      timescale:        [{ day: -27...0 }, { day: -55..-28 }],
      inherits_from:    :last_8_weeks_gas_comparison_temperature_compensated
    },
    last_28_days_gas_comparison_temperature_compensated_column: {
      chart1_type:      :line,
      inherits_from:    :last_28_days_gas_comparison_temperature_compensated_line
    },
=end
    #==============================================================
    sprint2_last_2_weeks_electricity_by_datetime: {
      name:             'Compare last 2 weeks by time of day - line chart (Electricity)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -1 }],
      x_axis:           :datetime,
      meter_definition: :allelectricity,
      yaxis_units:      :£,
      yaxis_scaling:    :none
    },
    sprint2_last_2_weeks_electricity_by_datetime_column: {
      name:             'Compare last 2 weeks by time of day - line chart (Electricity)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_datetime,
      chart1_type:      :column
    },
    sprint2_last_2_weeks_electricity_by_day_line: {
      name:             'Compare last 2 weeks by day - line chart (Electricity)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_datetime,
      x_axis:           :day
    },
    sprint2_last_2_weeks_electricity_by_day_column: {
      name:             'Compare last 2 weeks by day - column chart (Electricity)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_day_line,
      chart1_type:      :column
    },
    sprint2_last_2_weeks_gas_by_datetime: {
      name:             'Compare last 2 weeks by time of day - line chart (Gas)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_datetime,
      meter_definition: :allheat
    },
    sprint2_last_2_weeks_gas_by_datetime_column: {
      name:             'Compare last 2 weeks by time of day - line chart (Gas)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_datetime_column,
      meter_definition: :allheat
    },
    sprint2_last_2_weeks_gas_by_day_line: {
      name:             'Compare last 2 weeks by day - line chart (Gas)',
      inherits_from:    :sprint2_last_2_weeks_electricity_by_day_line,
      meter_definition: :allheat
    },
    sprint2_gas_comparison:  {
      name:             'Comparison of out of hour',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      timescale:        :year,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :£,
      yaxis_scaling:    :none
    }
  }.freeze
end
