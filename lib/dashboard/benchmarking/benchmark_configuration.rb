require_relative './benchmark_content_base.rb'
require_relative './benchmark_content_general.rb'
module Benchmarking
  class BenchmarkManager

    def self.chart_table_config(name)
      config = CHART_TABLE_CONFIG[name]
    end

    def self.chart_column?(column_definition)
      y1_axis_column?(column_definition) || y2_axis_column?(column_definition)
    end

    def self.y1_axis_column?(column_definition)
      column_definition?(column_definition, :chart_data) && !y2_axis_column?(column_definition)
    end

    def self.y2_axis_column?(column_definition)
      column_definition?(column_definition, :y2_axis)
    end

    def self.has_y2_column?(definition)
      definition[:columns].any? { |column_definition| y2_axis_column?(column_definition) }
    end

    def self.column_definition?(column_definition, key)
      column_definition.key?(key) && column_definition[key]
    end

    def self.available_pages(filter_out = nil)
      all_pages = CHART_TABLE_CONFIG.clone
      all_pages = all_pages.select{ |name, config| !filter_out?(config, filter_out.keys[0], filter_out.values[0]) } unless filter_out.nil?
      all_pages.transform_values{ |config| config[:name] }
    end

    def self.filter_out?(config, key, value)
      config.key?(key) && config[key] == value
    end

    # complex sort, so schools with missing meters, compare
    # their fuel type only and not on a total basis
    def self.sort_energy_costs(row1, row2)
      # row = [name, electric, gas, storage heaters, etc.....]
      row1a = [row1[1], [row1[2], row1[3]].compact.sum] # combined gas and storage heaters
      row2a = [row2[1], [row2[2], row2[3]].compact.sum]
      return  0 if row1a.compact.empty? && row2a.compact.empty?
      return +1 if row2a.compact.empty?
      return -1 if row1a.compact.empty?
      if row1a.compact.length == row2a.compact.length
        row1a.compact.sum <=> row2a.compact.sum
      elsif row1a[0].nil? || row2a[0].nil? # compare [nil, val] with [val1, val2] => val <=> val2
        row1a[1] <=> row2a[1]
      else                # compare [val, nil] with [val1, val2] => val <=> val1
        row1a[0] <=> row2a[0]
      end
    end

    CHART_TABLE_CONFIG = {
      annual_energy_costs_per_pupil: {
        benchmark_class:  BenchmarkContentEnergyPerPupil,
        name:     'Annual energy use per pupil',
        columns:  [
          { data: 'addp_name',              name: 'School name', units: String, chart_data: true },
          { data: ->{ elba_£pup },          name: 'Annual electricity GBP/pupil', units: :£, chart_data: true },
          { data: ->{ gsba_£pup },          name: 'Annual gas GBP/pupil', units: :£, chart_data: true },
          { data: ->{ shan_£pup },          name: 'Annual storage heater GBP/pupil', units: :£, chart_data: true },
          { data: ->{ enba_£pup },          name: 'Annual energy GBP/pupil', units: :£},
          { data: ->{ sum_data([elba_£pup, gsba_n£pp, shan_n£pp]) }, name: 'Annual energy GBP/pupil (temperature compensated)', units: :£},
          { data: ->{ sum_data([elba_kpup, gsba_kpup, shan_kpup]) }, name: 'Annual energy kWh/pupil', units: :kwh},
          { data: ->{ sum_data([elba_cpup, gsba_cpup, shan_cpup]) }, name: 'Annual energy kgCO2/pupil', units: :kwh},
          { data: ->{ addp_stpn },          name: 'Type',   units: String },
          { data: ->{ enba_ratg },          name: 'rating', units: Float, y2_axis: true },
        ],
        sort_by:  method(:sort_energy_costs),
        type: %i[chart table],
        drilldown:  { adult_dashboard: :benchmark, content: AdviceBenchmark }
      },
      annual_energy_costs: {
        benchmark_class:  BenchmarkContentTotalAnnualEnergy,
        name:     'Annual energy costs',
        columns:  [
          { data: 'addp_name',              name: 'School name', units: String, chart_data: true },
          { data: ->{ elba_£lyr },          name: 'Annual Electricity GBP', units: :£, chart_data: true },
          { data: ->{ gsba_£lyr },          name: 'Annual Gas GBP', units: :£, chart_data: true },
          { data: ->{ shan_£lyr },          name: 'Annual Storage Heater GBP', units: :£, chart_data: true },
          { data: ->{ enba_£lyr },          name: 'Total Energy Costs GBP', units: :£},
          { data: ->{ enba_£pup },          name: 'Annual energy GBP/pupil', units: :£},
          { data: ->{ enba_co2t },          name: 'Annual Energy CO2(tonnes)', units: :co2 },
          { data: ->{ enba_klyr },          name: 'Annual Energy kWh', units: :kwh },
          { data: ->{ addp_stpn },          name: 'Type',   units: String  },
          { data: ->{ addp_pupn },          name: 'Pupils', units: :pupils },
          { data: ->{ addp_flra },          name: 'Floor area', units: :m2 },
        ],
        sort_by:  [4],
        type: %i[chart table]
      },
      annual_energy_costs_per_floor_area: {
        benchmark_class:  BenchmarkContentEnergyPerPupil,
        name:     'Annual energy use per floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ enba_£fla },  name: 'Annual energy GBP/floor area', units: :£, chart_data: true },
          { data: ->{ enba_£lyr },  name: 'Annual energy cost GBP', units: :£},
          { data: ->{ enba_ratg },  name: 'rating', units: Float, y2_axis: true },
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      annual_electricity_costs_per_pupil: {
        benchmark_class:  BenchmarkContentElectricityPerPupil,
        name:     'Annual electricity use per pupil',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ elba_£pup },  name: 'Annual electricity GBP/pupil', units: :£, chart_data: true },
          { data: ->{ elba_£lyr },  name: 'Annual electricity GBP', units: :£},
          { data: ->{ elba_£esav }, name: 'Saving if matched exemplar school', units: :£ },
          { data: ->{ elba_ratg },  name: 'rating', units: Float, y2_axis: true },
        ],
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[chart table]
      },
      change_in_annual_electricity_consumption: {
        benchmark_class:  BenchmarkContentChangeInAnnualElectricityConsumption,
        name:     'Change in annual electricity consumption',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ (elba_£lyr - elba_£lyr_last_year) / elba_£lyr_last_year},  name: 'Change in annual electricity usage', units: :percent, chart_data: true },
          { data: ->{ elba_£lyr },  name: 'Annual electricity GBP (this year)', units: :£},
          { data: ->{ elba_£lyr_last_year },  name: 'Annual electricity GBP (last year)', units: :£}
        ],
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[chart table]
      },
      annual_electricity_out_of_hours_use: {
        benchmark_class: BenchmarkContentElectricityOutOfHoursUsage,
        name:     'Electricity out of hours use',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String, chart_data: true   },
          { data: ->{ eloo_sdop },  name: 'School Day Open',              units: :percent, chart_data: true },
          { data: ->{ eloo_sdcp },  name: 'School Day Closed',            units: :percent, chart_data: true },
          { data: ->{ eloo_holp },  name: 'Holiday',                      units: :percent, chart_data: true },
          { data: ->{ eloo_wkep },  name: 'Weekend',                      units: :percent, chart_data: true },
          { data: ->{ eloo_aoo£ },  name: 'Annual out of hours cost',     units: :£ },
          { data: ->{ eloo_esv£ },  name: 'Saving if improve to exemplar',units: :£ },
          { data: ->{ eloo_ratg },  name: 'rating',                       units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      recent_change_in_baseload: {
        benchmark_class: BenchmarkContentChangeInBaseloadSinceLastYear,
        name:     'Last week\'s baseload versus average of last year (% difference)',
        columns:  [
          { data: 'addp_name', name: 'School name', units: String, chart_data: true },
          { data: ->{ elbc_bspc }, name: 'Change in baseload last week v. year percent', units: :percent, chart_data: true},
          { data: ->{ elbc_blly }, name: 'Average baseload last year kW', units: :kw},
          { data: ->{ elbc_bllw }, name: 'Average baseload last week kW', units: :kw},
          { data: ->{ elbc_blch }, name: 'Change in baseload last week v. year kW', units: :kw},
          { data: ->{ elbc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      baseload_per_pupil: {
        benchmark_class: BenchmarkContentBaseloadPerPupil,
        name:     'Baseload per pupil',
        columns:  [
          { data: 'addp_name', name: 'School name', units: String, chart_data: true },
          { data: ->{ elbb_blpp * 1000.0 }, name: 'Baseload per pupil (W)', units: :w, chart_data: true},
          { data: ->{ elbb_lygb },  name: 'Annual cost of baseload', units: :£},
          { data: ->{ elbb_lykw },  name: 'Average baseload kW', units: :w},
          { data: ->{ elbb_svex },  name: 'Saving if moved to exemplar', units: :£},
          { data: ->{ elbb_lygb },  name: 'Annual cost of baseload', units: :£},
          { data: ->{ elbb_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      summer_holiday_electricity_analysis: {
        benchmark_class: BenchmarkContentSummerHolidayBaseloadAnalysis,
        name:     'Experimental analysis of reductions in baseload over summer holidays',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String },
          { data: ->{ shol_ann£ },  name: 'Annualised £ value of summer holiday reduction',    units: :£, chart_data: true },
          { data: ->{ shol_hol£ },  name: 'Saving during summer holiday from baseload reduction',  units: :£ },
          { data: ->{ shol_kwrd },  name: 'Reduction in baseload over summer holidays', units: :kw },
          { data: ->{ shol_rrat },  name: 'Size of reduction rating',  units: Float },
          { data: ->{ shol_trat },  name: 'Rating based on number of recent years with reduction',  units: Float },
          { data: ->{ shol_ratg },  name: 'Overall rating',  units: Float },

        ],
        sort_by: [1],
        type: %i[table]
      },
      annual_heating_costs_per_floor_area: {
        benchmark_class:  BenchmarkContentHeatingPerFloorArea,
        name:     'Annual heating cost per floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name',    units: String, chart_data: true },
          { data: ->{ sum_data([gsba_n£m2, shan_n£m2], true) },  name: 'Annual gas/storage heater GBP/pupil (temp compensated)', units: :£, chart_data: true },
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr], true) },  name: 'Annual cost GBP', units: :£},
          { data: ->{ sum_data([gsba_s£ex, shan_s£ex], true) },  name: 'Saving if matched exemplar school', units: :£ },
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr], true) },  name: 'Annual cost GBP', units: :£},
          { data: ->{ sum_data([gsba_klyr, shan_klyr], true) },  name: 'Annual consumption kWh', units: :kwh},
          { data: ->{ sum_data([gsba_co2y, shan_co2y], true) / 1000.0 },  name: 'Annual carbon emissions (tonnes CO2)', units: :co2},
          { data: ->{ or_nil([gsba_ratg, shan_ratg]) },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      change_in_annual_heating_consumption: {
        benchmark_class:  BenchmarkContentChangeInAnnualHeatingConsumption,
        name:     'Change in annual heating consumption',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ percent_change([gsba_£lyr_last_year, shan_£lyr_last_year], [gsba_£lyr, shan_£lyr], true) },  name: 'Change in annual gas/storage heater usage', units: :percent, chart_data: true },
          { data: ->{ gsba_£lyr },  name: 'Annual gas costs GBP (this year)', units: :£},
          { data: ->{ gsba_£lyr_last_year },  name: 'Annual gas costs GBP (last year)', units: :£},
          { data: ->{ shan_£lyr },  name: 'Annual storage heater costs GBP (this year)', units: :£},
          { data: ->{ shan_£lyr_last_year },  name: 'Annual gas costs GBP (last year)', units: :£},
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr]) - sum_data([gsba_£lyr_last_year, shan_£lyr_last_year]) },  name: 'Change in heating costs between last 2 years', units: :£}
        ],
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[chart table]
      },
      annual_gas_out_of_hours_use: {
        benchmark_class: BenchmarkContentGasOutOfHoursUsage,
        name:     'Gas: out of hours use',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true },
          { data: ->{ gsoo_sdop },  name: 'School Day Open',              units: :percent, chart_data: true },
          { data: ->{ gsoo_sdcp },  name: 'School Day Closed',            units: :percent, chart_data: true },
          { data: ->{ gsoo_holp },  name: 'Holiday',                      units: :percent, chart_data: true },
          { data: ->{ gsoo_wkep },  name: 'Weekend',                      units: :percent, chart_data: true },
          { data: ->{ gsoo_aoo£ },  name: 'Annual out of hours cost',     units: :£ },
          { data: ->{ gsoo_esv£ },  name: 'Saving if improve to exemplar',units: :£ },
          { data: ->{ gsoo_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      annual_storage_heater_out_of_hours_use: {
        benchmark_class: BenchmarkContentStorageHeaterOutOfHoursUsage,
        name:     'Storage heater out of hours use',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true },
          { data: ->{ shoo_sdop },  name: 'School Day Open',              units: :percent, chart_data: true },
          { data: ->{ shoo_sdcp },  name: 'Overnight charging',           units: :percent, chart_data: true },
          { data: ->{ shoo_holp },  name: 'Holiday',                      units: :percent, chart_data: true },
          { data: ->{ shoo_wkep },  name: 'Weekend',                      units: :percent, chart_data: true },
          { data: ->{ sum_data([shoo_ahl£, shoo_awk£], true)  },  name: 'Annual weekend and holiday costs', units: :£ },
          { data: ->{ shoo_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      heating_coming_on_too_early: {
        benchmark_class:  BenchmarkHeatingComingOnTooEarly,
        name:     'Heating start time (potentially coming on too early in morning)',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true },
          { data: ->{ hthe_htst },  name: 'Average heating start time (last week)', units: :timeofday, chart_data: true },
          { data: ->{ opts_avhm },  name: 'Average heating start time last year',   units: :timeofday },
          { data: ->{ hthe_oss£ },  name: 'Annual saving if improve to exemplar',units: :£ },
          { data: ->{ hthe_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      optimum_start_analysis: {
        benchmark_class:  BenchmarkOptimumStartAnalysis,
        filter_out:     :dont_make_available_directly,
        name:     'Optimum start analysis',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String, chart_data: true },
          { data: ->{ opts_avhm },  name: 'Average heating start time last year',    units: :timeofday, chart_data: true },
          { data: ->{ opts_sdst },  name: 'Standard deviation of start time - hours, last year',  units: :opt_start_standard_deviation },
          { data: ->{ opts_ratg },  name: 'Optimum start rating', units: Float },
          { data: ->{ opts_rmst },  name: 'Regression model optimum start time',  units: :morning_start_time },
          { data: ->{ opts_rmss },  name: 'Regression model optimum start sensitivity to outside temperature',  units: :optimum_start_sensitivity },
          { data: ->{ opts_rmr2 },  name: 'Regression model optimum start r2',  units: :r2 },
          { data: ->{ hthe_htst },  name: 'Average heating start time last week', units: :timeofday},
        ],
        sort_by: [1],
        type: %i[chart table]
      },
      thermostat_sensitivity: {
        benchmark_class:  BenchmarkContentThermostaticSensitivity,
        name:     'Annual saving through 1C reduction in thermostat temperature',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true },
          { data: ->{ htsa_td1c },  name: 'Annual saving per 1C reduction in thermostat', units: :£, chart_data: true },
          { data: ->{ htsa_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      length_of_school_day_heating_season: {
        benchmark_class:  BenchmarkContentLengthOfHeatingSeason,
        name:     'Number of days heating was on last year',
        columns:  [
          { data: 'addp_name',                   name: 'School name',           units: String, chart_data: true },
          { data: ->{ htsd_hdyr },  name: 'No. days heating on last year', units: :days, chart_data: true },
          { data: ->{ htsd_svav },  name: 'Saving through reducing season to average', units: :£ },
          { data: ->{ htsd_svex },  name: 'Saving through reducing season to exemplar', units: :£ },
          { data: ->{ htsd_svep },  name: 'Saving through reducing season to exemplar', units: :percent },
          { data: ->{ htsd_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        number_non_null_columns_for_filtering_tables: 3,
        sort_by: [1],
        type: %i[chart table]
      },
      thermostatic_control: {
        benchmark_class:  BenchmarkContentThermostaticControl,
        name:     'Quality of thermostatic control',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ or_nil([httc_r2, shtc_r2]) },    name: 'Thermostatic R2', units: Float,  chart_data: true },
          { data: ->{ sum_data([httc_sav£, shtc_sav£], true) },  name: 'Saving through improved thermostatic control', units: :£ },
          { data: ->{ httc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[chart table]
      },
      hot_water_efficiency: {
        benchmark_class:  BenchmarkContentHotWaterEfficiency,
        name:     'Hot Water Efficiency',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ hotw_ppyr },  name: 'Cost per pupil', units: :£, chart_data: true},
          { data: ->{ hotw_eff  },  name: 'Efficiency of system', units: :percent},
          { data: ->{ hotw_gsav },  name: 'Saving improving timing', units: :£},
          { data: ->{ hotw_esav },  name: 'Saving with POU electric hot water', units: :£},
          { data: ->{ hotw_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      electricity_meter_consolidation_opportunities: {
        benchmark_class:  BenchmarkContentElectricityMeterConsolidation,
        name:     'Opportunities for electricity meter consolidation',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ emtc_sav£ },  name: 'Potential max annual saving £', units: :£,  chart_data: true },
          { data: ->{ emtc_mets },  name: 'Number of electricity meters', units: :meters },
          { data: ->{ emtc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      gas_meter_consolidation_opportunities: {
        benchmark_class:  BenchmarkContentGasMeterConsolidation,
        name:     'Opportunities for gas meter consolidation',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ gmtc_sav£ },  name: 'Potential max annual saving £', units: :£,  chart_data: true },
          { data: ->{ gmtc_mets },  name: 'Number of gas meters', units: :meters },
          { data: ->{ gmtc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      differential_tariff_opportunity: {
        benchmark_class:  BenchmarkContentDifferentialTariffOpportunity,
        name:     'Benefit of moving to or away from a differential tariff',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ dtaf_sav£ },  name: 'Potential annual saving £', units: :£,  chart_data: true },
          { data: ->{ dtaf_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_electricity_consumption_recent_school_weeks: {
        benchmark_class:  BenchmarkContentChangeInElectricityConsumptionSinceLastSchoolWeek,
        name:     'Change in electricity consumption since last school week',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ eswc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ eswc_dif£ },  name: 'Change £', units: :£ },
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_electricity_holiday_consumption_previous_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetweenLast2Holidays,
        name:     'Change in electricity consumption between the 2 most recent holidays',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ ephc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ ephc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ ephc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_electricity_holiday_consumption_previous_years_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetween2HolidaysYearApart,
        name:     'Change in electricity consumption between this holiday and the same holiday the previous year',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ epyc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ epyc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ epyc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_gas_consumption_recent_school_weeks: {
        name:     'Change in gas consumption since last school week',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ gswc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ gswc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gswc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_gas_holiday_consumption_previous_holiday: {
        name:     'Change in gas consumption between the 2 most recent holidays',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ gphc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ gphc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gphc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_gas_holiday_consumption_previous_years_holiday: {
        name:     'Change in gas consumption between this holiday and the same the previous year',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ gpyc_difp },  name: 'Change %', units: :percent, chart_data: true },
          { data: ->{ gpyc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gpyc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      electricity_peak_kw_per_pupil: {
        name:     'Peak school day electricity comparison kW/floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String, chart_data: true },
          { data: ->{ epkb_kwfa },  name: 'kW/floor area',    units: :kw, chart_data: true },
          { data: ->{ epkb_kwsc },  name: 'average peak kw',  units: :kw },
          { data: ->{ epkb_kwex },  name: 'exemplar peak kw', units: :kw },
          { data: ->{ epkb_tex£ },  name: 'saving if match exemplar (£)', units: :£ },
          { data: ->{ epkb_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      solar_pv_benefit_estimate: {
        name:     'Benefit of estimated optimum size solar PV installation',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String },
          { data: ->{ sole_opvk },  name: 'kWp',    units: :kwp},
          { data: ->{ sole_opvy },  name: 'payback (years)',  units: :years },
          { data: ->{ sole_opvp },  name: 'Percent reduction in mains consumption', units: :percent }
        ],
        sort_by: [1],
        type: %i[table]
      }
    }.freeze
=begin

      AlertSchoolWeekComparisonElectricity          => 'eswc',
      AlertPreviousHolidayComparisonElectricity     => 'ephc',
      AlertPreviousYearHolidayComparisonElectricity => 'epyc',
      AlertSchoolWeekComparisonGas                  => 'gswc',
      AlertPreviousHolidayComparisonGas             => 'gphc',
      AlertPreviousYearHolidayComparisonGas         => 'gpyc',

      AlertElectricityPeakKWVersusBenchmark         => 'epkb'

      AlertHeatingOnOff                             => 'htoo',
      AlertWeekendGasConsumptionShortTerm           => 'gswe',
      AlertMeterASCLimit                            => 'masc',
      AlertAdditionalPrioritisationData             => 'addp',
=end
  end
end
