# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  include Logging
  attr_reader :standard_charts, :school

  STANDARD_CHARTS = [
    :day,
    :group_by_month,
    :group_by_week,
    :day_of_week,
    :benchmark,
    :daytype_breakdown,
    :thermostatic,
    :cusum,
    :baseload,
    :summer_hot_water,
    :intraday_aggregate,
    :intraday
  ].freeze

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
      # timescale:        :year
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
      y2_axis:          :degreedays
    },
    electricity_longterm_trend: {
      name:             'Electricity: long term trends',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
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
      yaxis_scaling:    :per_200_pupils
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
    thermostatic: {
      name:             'Thermostatic (Heating Season, School Day)',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: true },
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
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
    cusum: {
      name:             'CUSUM',
      chart1_type:      :line,
      meter_definition: :allheat,
      series_breakdown: :cusum,
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
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
    intraday_electricity_simulator_ict: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :submeter,
      timescale:        :year,
      x_axis:           :intraday,
      meter_definition: :electricity_simulator,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      filter:            { daytype: :occupied, submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
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
      filter:            { submeter: ['Solar PV'] }
    },
    intraday_electricity_simulator_solar_pv_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Solar PV)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Solar PV'] }
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
      name:             'Electricity Use By Day of the Week (Actual Usage over last year)',
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
      timescale:        [{ day: Date.new(2018, 3, 16) }, { day: Date.new(2018, 3, 6) } ], # fixed dates: one relatively mild, one relatively cold
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
    }
  }.freeze

  def initialize(school, show_reconciliation_values = true)
    @school = school
    @show_reconciliation_values = show_reconciliation_values
  end

  def run_standard_charts
    chart_definitions = []
    STANDARD_CHARTS.each do |chart_param|
      chart_definitions.push(run_standard_chart(chart_param))
    end
    chart_definitions
  end

  def run_chart_group(chart_param)
    if chart_param.is_a?(Symbol)
      run_standard_chart(chart_param)
    elsif chart_param.is_a?(Hash)
      run_composite_chart(chart_param)
    end
  end

  def run_composite_chart(chart_group)
    puts "Running composite chart group #{chart_group[:name]}"
    chart_group_result = {}
    chart_group_result[:config] = chart_group
    chart_group_result[:charts] = []
    chart_group[:chart_group][:charts].each do |chart_param|
      chart = run_standard_chart(chart_param)
      ap(chart, limit: 20, color: { float: :red }) if logger.debug?
      chart_group_result[:charts].push(chart)
    end

    if chart_group[:advice_text]
      advice = DashboardChartAdviceBase.advice_factory_group(chart_group[:type], @school, chart_group, chart_group_result[:charts])

      unless advice.nil?
        advice.generate_advice
        chart_group_result[:advice_header] = advice.header_advice
        chart_group_result[:advice_footer] = advice.footer_advice
      end
    end

    ap(chart_group_result, limit: 20, color: { float: :red }) if logger.debug?
    chart_group_result
  end

  def run_standard_chart(chart_param)
    chart_config = STANDARD_CHART_CONFIGURATION[chart_param].dup
    while chart_config.key?(:inherits_from)
      base_chart_config_param = chart_config[:inherits_from]
      base_chart_config = STANDARD_CHART_CONFIGURATION[base_chart_config_param].dup
      chart_config.delete(:inherits_from)
      chart_config = base_chart_config.merge(chart_config)
    end
    chart_definition = run_chart(chart_config, chart_param)
    chart_definition
  end

  def run_chart(chart_config, chart_param)
    # puts 'Chart configuration:'
    ap(chart_config, limit: 20, color: { float: :red }) if logger.debug?

    begin
      aggregator = Aggregator.new(@school, chart_config, @show_reconciliation_values)

      # rubocop:disable Lint/AmbiguousBlockAssociation
      puts Benchmark.measure { aggregator.aggregate }
      # rubocop:enable Lint/AmbiguousBlockAssociation

      graph_data = configure_graph(aggregator, chart_config, chart_param)

      graph_data
    rescue StandardError => e
      puts "Unable to create chart", e
      puts e.backtrace
      nil
    end
  end

  def configure_graph(aggregator, chart_config, chart_param)
    graph_definition = {}

    graph_definition[:title]          = chart_config[:name] + ' ' + aggregator.title_summary

    graph_definition[:x_axis]         = aggregator.x_axis
    graph_definition[:x_data]         = aggregator.bucketed_data
    graph_definition[:chart1_type]    = chart_config[:chart1_type]
    graph_definition[:chart1_subtype] = chart_config[:chart1_subtype]
    # graph_definition[:yaxis_units]    = chart_config[:yaxis_units]
    # graph_definition[:yaxis_scaling]  = chart_config[:yaxis_scaling]
    graph_definition[:y_axis_label]   = chart_config[:y_axis_label]
    graph_definition[:config_name]    = chart_param

    if chart_config.key?(:y2_axis)
      graph_definition[:y2_chart_type] = :line
      graph_definition[:y2_data] = aggregator.y2_axis
    end
    if !aggregator.data_labels.nil?
      graph_definition[:data_labels] = aggregator.data_labels
    end

    graph_definition[:configuration] = chart_config

    advice = DashboardChartAdviceBase.advice_factory(chart_param, @school, chart_config, graph_definition, chart_param)

    unless advice.nil?
      advice.generate_advice
      graph_definition[:advice_header] = advice.header_advice
      graph_definition[:advice_footer] = advice.footer_advice
    end
    graph_definition
  end
end
