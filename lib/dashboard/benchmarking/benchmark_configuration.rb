require_relative './benchmark_content_base.rb'
require_relative './benchmark_content_general.rb'
require_relative '../charting_and_reports/tables/management_summary_table.rb'

module Benchmarking
  class BenchmarkManager

    def self.chart_table_config(name)
      config = CHART_TABLE_CONFIG[name]
    end

    def self.chart_column?(column_definition)
      y1_axis_column?(column_definition) || y2_axis_column?(column_definition)
    end

    def self.aggregate_column?(column_definition)
      column_definition?(column_definition, :aggregate_column) &&
      column_definition[:aggregate_column] == :dont_display_in_table_or_chart
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

    def self.structured_pages(user_type_hash, filter_out = nil)
      CHART_TABLE_GROUPING.map do |group|
        visible_benchmarks = if ContentBase.analytics_user?(user_type_hash)
          group[:benchmarks]
        else
          group[:benchmarks].select { |key| !CHART_TABLE_CONFIG[key].fetch(:analytics_user_type, false) }
        end
        {
          name:  group[:name],
          benchmarks: visible_benchmarks.map{ |key| [key, CHART_TABLE_CONFIG[key][:name]] }.to_h
        }
      end
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

    def self.sort_by_nil(row1, row2)
      if row1[3].nil? && row2[3].nil?
        row1[2] <=> row2[2] # sort by this year kWh
      else
        nil_to_infinity(row1[3]) <=> nil_to_infinity(row2[3])
      end
    end

    def self.nil_to_infinity(val)
      val.nil? ? Float::INFINITY : val
    end

    CHART_TABLE_GROUPING = [
      {
        name:       'Energy Cost Benchmarks',
        benchmarks: %i[
          annual_energy_costs_per_pupil
          annual_energy_costs
          annual_energy_costs_per_floor_area
        ]
      },
      {
        name:       'Change in Energy Use',
        benchmarks: %i[
          change_in_energy_use_since_joined_energy_sparks
          change_in_energy_since_last_year
          change_in_electricity_since_last_year
          change_in_gas_since_last_year
          change_in_storage_heaters_since_last_year
          change_in_solar_pv_since_last_year
          change_in_co2_emissions_since_last_year
          holiday_usage_last_year
        ]
      },
      {
        name:       'Electricity Benchmarks',
        benchmarks: %i[
          annual_electricity_costs_per_pupil
          change_in_annual_electricity_consumption
          annual_electricity_out_of_hours_use
          recent_change_in_baseload
          baseload_per_pupil
          seasonal_baseload_variation
          weekday_baseload_variation
          summer_holiday_electricity_analysis
          electricity_peak_kw_per_pupil
          solar_pv_benefit_estimate
          refrigeration
          electricity_targets
          change_in_electricity_consumption_recent_school_weeks
          change_in_electricity_holiday_consumption_previous_holiday
          change_in_electricity_holiday_consumption_previous_years_holiday
          electricity_consumption_during_holiday
        ]
      },
      {
        name:       'Gas and Storage Heater Benchmarks',
        benchmarks: %i[
          annual_heating_costs_per_floor_area
          change_in_annual_heating_consumption
          annual_gas_out_of_hours_use
          annual_storage_heater_out_of_hours_use
          heating_coming_on_too_early
          thermostat_sensitivity
          heating_in_warm_weather
          thermostatic_control
          hot_water_efficiency
          change_in_gas_consumption_recent_school_weeks
          change_in_gas_holiday_consumption_previous_holiday
          change_in_gas_holiday_consumption_previous_years_holiday
          gas_consumption_during_holiday
          storage_heater_consumption_during_holiday
        ]
      },
      {
        name:       'Metering Potential Cost Savings',
        benchmarks: %i[
          electricity_meter_consolidation_opportunities
          gas_meter_consolidation_opportunities
          differential_tariff_opportunity
        ]
      }
    ]

    CHART_TABLE_CONFIG = {
      annual_energy_costs_per_pupil: {
        benchmark_class:  BenchmarkContentEnergyPerPupil,
        name:     'Annual energy use per pupil',
        columns:  [
          { data: 'addp_name',              name: 'School name', units: String, chart_data: true, content_class: AdviceBenchmark },
          { data: ->{ elba_£pup },          name: 'Annual electricity £/pupil', units: :£, chart_data: true },
          { data: ->{ gsba_£pup },          name: 'Annual gas £/pupil', units: :£, chart_data: true },
          { data: ->{ shan_£pup },          name: 'Annual storage heater £/pupil', units: :£, chart_data: true },
          { data: ->{ enba_£pup },          name: 'Annual energy £/pupil', units: :£},
          { data: ->{ sum_data([elba_£pup, gsba_n£pp, shan_n£pp]) }, name: 'Annual energy £/pupil (temperature compensated)', units: :£},
          { data: ->{ sum_data([elba_kpup, gsba_kpup, shan_kpup]) }, name: 'Annual energy kWh/pupil', units: :kwh},
          { data: ->{ sum_data([elba_cpup, gsba_cpup, shan_cpup]) }, name: 'Annual energy kgCO2/pupil', units: :kwh},
          { data: ->{ addp_stpn },          name: 'Type',   units: String },
          { data: ->{ enba_ratg },          name: 'rating', units: Float, y2_axis: true },
        ],
        where:   ->{ !enba_£pup.nil? },
        sort_by:  method(:sort_energy_costs),
        type: %i[chart table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark }
      },
      annual_energy_costs: {
        benchmark_class:  BenchmarkContentTotalAnnualEnergy,
        name:     'Annual energy costs',
        columns:  [
          { data: 'addp_name',              name: 'School name', units: String, chart_data: true },
          { data: ->{ elba_£lyr },          name: 'Annual Electricity £', units: :£, chart_data: true },
          { data: ->{ gsba_£lyr },          name: 'Annual Gas £', units: :£, chart_data: true },
          { data: ->{ shan_£lyr },          name: 'Annual Storage Heater £', units: :£, chart_data: true },
          { data: ->{ enba_£lyr },          name: 'Total Energy Costs £', units: :£},
          { data: ->{ enba_£pup },          name: 'Annual energy £/pupil', units: :£},
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
        benchmark_class:  BenchmarkContentEnergyPerFloorArea,
        name:     'Annual energy use per floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },
          { data: ->{ enba_£fla },  name: 'Annual energy £/floor area', units: :£, chart_data: true },
          { data: ->{ enba_£lyr },  name: 'Annual energy cost £', units: :£},
          { data: ->{ enba_ratg },  name: 'rating', units: Float, y2_axis: true },
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      change_in_energy_use_since_joined_energy_sparks: {
        benchmark_class:  BenchmarkContentChangeInEnergyUseSinceJoined,
        name:     'Change in energy use since the school joined Energy Sparks',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: :short_school_name, chart_data: true },
          { data: ->{ enba_sact },  name: 'Energy Sparks join date', units: :date_mmm_yyyy },
          { data: ->{ enba_kxap },  name: 'Energy (total)',   units: :relative_percent_0dp, chart_data: true, content_class: AdviceBenchmark },
          { data: ->{ enba_keap },  name: 'Electricity',      units: :relative_percent_0dp },
          { data: ->{ enba_kgap },  name: 'Gas',              units: :relative_percent_0dp },
          { data: ->{ enba_khap },  name: 'Storage heaters',  units: :relative_percent_0dp },
          { data: ->{ enba_ksap },  name: 'Solar PV',         units: :relative_percent_0dp }
        ],
        column_groups: [
          { name: '',                                     span: 2 },
          { name: 'Change since joined Energy Sparks',    span: 5 },
        ],
        treat_as_nil:   [ManagementSummaryTable::NO_RECENT_DATA_MESSAGE, ManagementSummaryTable::NOT_ENOUGH_DATA_MESSAGE], # from ManagementSummaryTable:: not referenced because not on path
        sort_by:  [2],
        type: %i[chart table]
      },
      # second chart and table on page defined by change_in_energy_use_since_joined_energy_sparks above
      # not displayed on its own as a separate comparison
      change_in_energy_use_since_joined_energy_sparks_full_data: {
        benchmark_class:  BenchmarkContentChangeInEnergyUseSinceJoinedFullData,
        filter_out:       :dont_make_available_directly,
        name:     'breakdown in the change in energy use since the school joined Energy Sparks',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: :short_school_name, chart_data: true },
          { data: ->{ enba_sact },  name: 'Energy Sparks join date', units: :date_mmm_yyyy },

          { data: ->{ enba_kea }, name: 'Year before joined',       units: :kwh },
          { data: ->{ enba_ke0 }, name: 'Last year',                units: :kwh },
          { data: ->{ enba_keap}, name: 'Change (excluding solar)', units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kga }, name: 'Year before joined', units: :kwh },
          { data: ->{ enba_kg0 }, name: 'Last year',          units: :kwh },
          { data: ->{ enba_kgap}, name: 'Change',             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kha }, name: 'Year before joined', units: :kwh },
          { data: ->{ enba_kh0 }, name: 'Last year',          units: :kwh },
          { data: ->{ enba_khap}, name: 'Change',             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_ksa }, name: 'Year before joined', units: :kwh },
          { data: ->{ enba_ks0 }, name: 'Last year',          units: :kwh },
          { data: ->{ enba_ksap}, name: 'Change',             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kxap },  name: 'Change',           units: :relative_percent_0dp, y2_axis: true }
        ],
        column_groups: [
          { name: '',                           span: 2 },
          { name: 'Electricity consumption',    span: 3 },
          { name: 'Gas consumption',            span: 3 },
          { name: 'Storage heater consumption', span: 3 },
          { name: 'Solar PV production',        span: 3 },
          { name: 'Total energy consumption',   span: 1 }
        ],
        sort_by:  [13],
        type: %i[chart table]
      },
      change_in_co2_emissions_since_last_year: {
        benchmark_class:  BenchmarkContentChangeInCO2SinceLastYear,
        name:     'Change in annual CO2 emissions since last year',
        columns:  [
          { data: 'addp_name',      name: 'School name',          units: String, chart_data: true },
          { data: ->{ enba_cxn },   name: 'CO2 (previous year)',  units: :co2 },
          { data: ->{ enba_cx0 },   name: 'CO2 (last year)',      units: :co2 },
          { data: ->{ enba_cxnp},   name: 'Change in annual CO2', units: :relative_percent_0dp, chart_data: true }
        ],
        sort_by:  [3],
        type: %i[chart table]
      },
      # second chart and table on page defined by change_in_co2_emissions_since_last_year above
      # not displayed on its own as a separate comparison
      change_in_co2_emissions_since_last_year_full_table: {
        benchmark_class:  BenchmarkContentChangeInCO2SinceLastYearFullData,
        filter_out:       :dont_make_available_directly,
        name:     'Breakdown of CO2 emissions change since last year',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true },

          { data: ->{ enba_cen }, name: 'Electricity CO2 (previous year)',                    units: :co2 },
          { data: ->{ enba_ce0 }, name: 'Electricity CO2 (last year)',                        units: :co2 },
          { data: ->{ enba_cenp}, name: 'Change in annual electricity CO2 (excluding solar)', units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_cgn },  name: 'Gas CO2 (previous year)',   units: :co2 },
          { data: ->{ enba_cg0 },  name: 'Gas CO2 (last year)',       units: :co2 },
          { data: ->{ enba_cgnp},  name: 'Change in annual gas CO2',  units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_chn },  name: 'Storage Heater CO2 (previous year)',  units: :co2 },
          { data: ->{ enba_ch0 },  name: 'Storage Heater CO2 (last year)',      units: :co2 },
          { data: ->{ enba_chnp},  name: 'Change in annual storage heater CO2', units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_csn },  name: 'Solar PV CO2 (previous year)',  units: :co2 },
          { data: ->{ enba_cs0 },  name: 'Solar PV CO2 (last year)',      units: :co2 },
          { data: ->{ enba_csnp},  name: 'Change in annual solar PV CO2', units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_cxnp},  name: 'Overall change', units: :relative_percent_0dp, y2_axis: true },
        ],
        sort_by:  [13],
        type: %i[chart table]
      },
      change_in_energy_since_last_year: {
        benchmark_class:  BenchmarkChangeInEnergySinceLastYear,
        name:     'Change in energy use since last year',
        columns:  [
          { data: 'addp_name',              name: 'School name', units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },
          { data: ->{ sum_if_complete([enba_ken, enba_kgn, enba_khn, enba_ksn], 
                                      [enba_ke0, enba_kg0, enba_kh0, enba_ks0]) }, name: 'previous year', units: :kwh },
          { data: ->{ sum_data([enba_ke0, enba_kg0, enba_kh0, enba_ks0]) }, name: 'last year', units: :kwh },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_ken, enba_kgn, enba_khn, enba_ksn],
                          [enba_ke0, enba_kg0, enba_kh0, enba_ks0]
                        ),
                        sum_data([enba_ke0, enba_kg0, enba_kh0, enba_ks0]),
                        true
                      )
                    },
                    name: 'change', units: :relative_percent_0dp
          },

          { data: ->{ sum_if_complete([enba_cen, enba_cgn, enba_chn, enba_csn], 
                                      [enba_ce0, enba_cg0, enba_ch0, enba_cs0]) }, name: 'previous year', units: :co2 },
          { data: ->{ sum_data([enba_ce0, enba_cg0, enba_ch0, enba_cs0]) }, name: 'last year', units: :co2 },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_cen, enba_cgn, enba_chn, enba_csn],
                          [enba_ce0, enba_cg0, enba_ch0, enba_cs0]
                        ),
                        sum_data([enba_ce0, enba_cg0, enba_ch0, enba_cs0]),
                        true
                      )
                    },
                    name: 'change', units: :relative_percent_0dp
          },

          { data: ->{ sum_if_complete([enba_pen, enba_pgn, enba_phn, enba_psn], 
                                      [enba_pe0, enba_pg0, enba_ph0, enba_ps0]) }, name: 'previous year', units: :£ },
          { data: ->{ sum_data([enba_pe0, enba_pg0, enba_ph0, enba_ps0]) }, name: 'last year', units: :£ },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_pen, enba_pgn, enba_phn, enba_psn],
                          [enba_pe0, enba_pg0, enba_ph0, enba_ps0]
                        ),
                        sum_data([enba_pe0, enba_pg0, enba_ph0, enba_ps0]),
                        true
                      )
                    },
                    name: 'change', units: :relative_percent_0dp
          },
          {
            data: ->{ 
              [
                enba_pe0.nil?     ? nil : 'E',
                enba_pg0.nil?     ? nil : 'G',
                enba_ph0.nil?     ? nil : 'SH',
                enba_solr == ''   ? nil : (enba_solr == 'synthetic' ? 's' : 'S')
              ].compact.join(' + ')
            },
            name: 'Fuel', units: String
          },
          { 
            data: ->{ 
              (enba_peap == ManagementSummaryTable::NO_RECENT_DATA_MESSAGE ||
               enba_pgap == ManagementSummaryTable::NO_RECENT_DATA_MESSAGE) ? 'Y' : ''
             },
             name: 'No recent data', units: String
          }
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 },
          { name: 'Metering', span: 2 },
        ],
        where:   ->{ !sum_data([enba_ke0, enba_kg0, enba_kh0, enba_ks0], true).nil? },
        sort_by:  method(:sort_by_nil),
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark }
      },
      change_in_electricity_since_last_year: {
        benchmark_class:  BenchmarkChangeInElectricitySinceLastYear,
        name:     'Change in electricity consumption since last year',
        columns:  [
          { data: 'addp_name',  name: 'School name', units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_ken },                          name: 'previous year',  units: :kwh },
          { data: ->{ enba_ke0 },                          name: 'last year',      units: :kwh },
          { data: ->{ percent_change(enba_ken, enba_ke0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_cen },                          name: 'previous year',  units: :co2 },
          { data: ->{ enba_ce0 },                          name: 'last year',      units: :co2 },
          { data: ->{ percent_change(enba_cen, enba_ce0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_pen },                          name: 'previous year',  units: :£ },
          { data: ->{ enba_pe0 },                          name: 'last year',      units: :£ },
          { data: ->{ percent_change(enba_pen, enba_pe0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_solr == 'synthetic' ? 'Y' : '' }, name: 'estimated',  units: String },
        ],
        column_groups: [
          { name: '',                       span: 1 },
          { name: 'kWh',                    span: 3 },
          { name: 'CO2 (kg)',               span: 3 },
          { name: '£',                      span: 3 },
          { name: 'Solar self consumption', span: 1 },
        ],
        where:   ->{ !enba_ken.nil? && enba_peap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark }
      },
      change_in_gas_since_last_year: {
        benchmark_class:  BenchmarkChangeInGasSinceLastYear,
        name:     'Change in gas consumption since last year',
        columns:  [
          { data: 'addp_name',  name: 'School name', units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_kgn  },                         name: 'previous year',  units: :kwh },
          { data: ->{ gsba_kpya },                         name: 'previous year temperature adjusted',  units: :kwh },
          { data: ->{ enba_kg0 },                          name: 'last year',      units: :kwh },

          { data: ->{ enba_cgn },                          name: 'previous year',  units: :co2 },
          { data: ->{ enba_cg0 },                          name: 'last year',      units: :co2 },

          { data: ->{ enba_pgn },                          name: 'previous year',  units: :£ },
          { data: ->{ enba_pg0 },                          name: 'last year',      units: :£ },

          { data: ->{ percent_change(enba_kgn, enba_kg0)}, name: 'unadjusted',    units: :relative_percent_0dp },
          { data: ->{ gsba_adpc },                         name: 'temperature adjusted', units: :relative_percent_0dp },
  #        { data: ->{ gsba_ddan },                         name: 'colder?',       units: :relative_percent_0dp },
        ],
        column_groups: [
          { name: '',                 span: 1 },
          { name: 'kWh',              span: 3 },
          { name: 'CO2 (kg)',         span: 2 },
          { name: '£',                span: 2 },
          { name: 'percent changed',  span: 2 },
        ],
        where:   ->{ !enba_kgn.nil? && enba_pgap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceGasLongTerm }
      },
      change_in_storage_heaters_since_last_year: {
        benchmark_class:  BenchmarkChangeInStorageHeatersSinceLastYear,
        name:     'Change in storage heater consumption since last year',
        columns:  [
          { data: 'addp_name',  name: 'School name', units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_khn },                          name: 'previous year',  units: :kwh },
          { data: ->{ enba_kh0 },                          name: 'last year',      units: :kwh },
          { data: ->{ percent_change(enba_khn, enba_kh0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_chn },                          name: 'previous year',  units: :co2 },
          { data: ->{ enba_ch0 },                          name: 'last year',      units: :co2 },
          { data: ->{ percent_change(enba_chn, enba_ch0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_phn },                          name: 'previous year',  units: :£ },
          { data: ->{ enba_ph0 },                          name: 'last year',      units: :£ },
          { data: ->{ percent_change(enba_phn, enba_ph0)}, name: 'change',         units: :relative_percent_0dp },
          { data: ->{ shan_ddan},                          name: 'colder?',        units: :relative_percent_0dp },
        ],
        column_groups: [
          { name: '',                       span: 1 },
          { name: 'kWh',                    span: 3 },
          { name: 'CO2 (kg}',               span: 3 },
          { name: '£',                      span: 3 },
        ],
        where:   ->{ !enba_khn.nil? && enba_psap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceStorageHeaters }
      },
      change_in_solar_pv_since_last_year: {
        benchmark_class:  BenchmarkChangeInSolarPVSinceLastYear,
        name:     'Change in solar PV production since last year',
        columns:  [
          { data: 'addp_name',  name: 'School name', units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_ksn },                          name: 'previous year',  units: :kwh },
          { data: ->{ enba_ks0 },                          name: 'last year',      units: :kwh },
          { data: ->{ percent_change(enba_ksn, enba_ks0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_csn },                          name: 'previous year',  units: :co2 },
          { data: ->{ enba_cs0 },                          name: 'last year',      units: :co2 },
          { data: ->{ percent_change(enba_csn, enba_cs0)}, name: 'change',         units: :relative_percent_0dp },

          { data: ->{ enba_solr == 'synthetic' ? 'Y' : '' }, name: 'estimated',  units: String },
        ],
        column_groups: [
          { name: '',                       span: 1 },
          { name: 'kWh',                    span: 3 },
          { name: 'CO2 (kg)',               span: 3 },
          { name: 'Solar',                  span: 1 },
        ],
        where:   ->{ !enba_ksn.nil? && enba_psap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceSolarPV }
      },
      annual_electricity_costs_per_pupil: {
        benchmark_class:  BenchmarkContentElectricityPerPupil,
        name:     'Annual electricity use per pupil',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ elba_£pup },  name: 'Annual electricity £/pupil', units: :£_0dp, chart_data: true },
          { data: ->{ elba_£lyr },  name: 'Annual electricity £', units: :£},
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
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ (elba_£lyr - elba_£pyr) / elba_£pyr},  name: 'Change in annual electricity usage', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ elba_£lyr },  name: 'Annual electricity £ (this year)', units: :£},
          { data: ->{ elba_£pyr },  name: 'Annual electricity £ (last year)', units: :£}
        ],
        where:   ->{ !elba_£pyr.nil? },
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[chart table]
      },
      refrigeration: {
        benchmark_class:  BenchmarkRefrigeration,
        name:     'Annual cost of running refrigeration',
        columns:  [
          { data:   'addp_name',    name: 'School name', units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ free_ann£ },  name: 'Estimate of annual refrigeration cost', units: :£, chart_data: true },
          { data: ->{ free_hol£ },  name: 'Saving over summer holiday', units: :£, chart_data: true },
          { data: ->{ -1.0 * free_kwrd },  name: 'Reduction in kW over summer holiday', units: :kw},
        ],
        analytics_user_type: true,
        where:   ->{ !free_kwrd.nil? },
        sort_by:  [1], # column 1 i.e. annual refrigeration costs
        type: %i[chart table]
      },
      electricity_targets: {
        benchmark_class:  BenchmarkElectricityTarget,
        name:     'Progress versus electricity target',
        columns:  [
          { data:   'addp_name',    name: 'School name', units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ etga_tptd },  name: 'Percent above or below target since target set', units: :relative_percent, chart_data: true },
          { data: ->{ etga_aptd },  name: 'Percent above or below last year',  units: :relative_percent},
          { data: ->{ etga_cktd },  name: 'kWh consumption since target set',  units: :kwh},
          { data: ->{ etga_tktd },  name: 'target kWh consumption',            units: :kwh},
          { data: ->{ etga_uktd },  name: 'last year kWh consumption',         units: :kwh},
          { data: ->{ etga_trsd },  name: 'start date for target',             units: :date},
        ],
        sort_by:  [1], # column 1 i.e. annual refrigeration costs
        type: %i[chart table]
      },
      annual_electricity_out_of_hours_use: {
        benchmark_class: BenchmarkContentElectricityOutOfHoursUsage,
        name:     'Electricity out of hours use',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String, chart_data: true, content_class: AdviceElectricityOutHours   },
          { data: ->{ eloo_sdop },  name: 'School Day Open',              units: :percent, chart_data: true },
          { data: ->{ eloo_sdcp },  name: 'School Day Closed',            units: :percent, chart_data: true },
          { data: ->{ eloo_holp },  name: 'Holiday',                      units: :percent, chart_data: true },
          { data: ->{ eloo_wkep },  name: 'Weekend',                      units: :percent, chart_data: true },
          { data: ->{ eloo_comp },  name: 'Community',                    units: :percent, chart_data: true },
          { data: ->{ eloo_com£ },  name: 'Community usage cost',         units: :£ },
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
          { data: 'addp_name', name: 'School name', units: String, chart_data: true, content_class: AdviceBaseload  },
          { data: ->{ elbc_bspc }, name: 'Change in baseload last week v. year (%)', units: :percent, chart_data: true},
          { data: ->{ elbc_blly }, name: 'Average baseload last year (kW)', units: :kw},
          { data: ->{ elbc_bllw }, name: 'Average baseload last week (kW)', units: :kw},
          { data: ->{ elbc_blch }, name: 'Change in baseload last week v. year (kW)', units: :kw},
          { data: ->{ elbc_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      baseload_per_pupil: {
        benchmark_class: BenchmarkContentBaseloadPerPupil,
        name:     'Baseload per pupil',
        columns:  [
          { data: 'addp_name', name: 'School name', units: String, chart_data: true, content_class: AdviceBaseload },
          { data: ->{ elbb_blpp * 1000.0 }, name: 'Baseload per pupil (W)', units: :w, chart_data: true},
          { data: ->{ elbb_lygb },  name: 'Annual cost of baseload', units: :£},
          { data: ->{ elbb_lykw },  name: 'Average baseload kW', units: :w},
          { data: ->{ [0.0, elbb_svex].max },  name: 'Saving if moved to exemplar', units: :£},
          { data: ->{ elbb_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        where:   ->{ !elbb_blpp.nil? },
        sort_by:  [1],
        type: %i[chart table]
      },
      seasonal_baseload_variation: {
        benchmark_class: BenchmarkSeasonalBaseloadVariation,
        name:     'Seasonal baseload variation',
        columns:  [
          { data: 'addp_name', name: 'School name', units: String, chart_data: true, content_class: AdviceBaseload },
          { data: ->{ sblv_sblp }, name: 'Percent increase on winter baseload over summer', units: :relative_percent, chart_data: true},
          { data: ->{ sblv_smbl },  name: 'Summer baseload kW', units: :kw},
          { data: ->{ sblv_wtbl },  name: 'Winter baseload kW', units: :kw},
          { data: ->{ sblv_cgbp },  name: 'Saving if same all year around', units: :£},
          { data: ->{ sblv_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      weekday_baseload_variation: {
        benchmark_class: BenchmarkWeekdayBaseloadVariation,
        name:     'Weekday baseload variation',
        columns:  [
          { data: 'addp_name', name: 'School name', units: String, chart_data: true, content_class: AdviceBaseload },
          { data: ->{ iblv_sblp }, name: 'Variation in baseload between days of week', units: :relative_percent, chart_data: true},
          { data: ->{ iblv_mnbk },  name: 'Min average weekday baseload kW', units: :kw},
          { data: ->{ iblv_mxbk },  name: 'Max average weekday baseload kW', units: :kw},
          { data: ->{ iblv_mnbd },  name: 'Day of week with minimum baseload', units: String},
          { data: ->{ iblv_mxbd },  name: 'Day of week with maximum baseload', units: String},
          { data: ->{ iblv_cgbp },  name: 'Potential saving', units: :£},
          { data: ->{ iblv_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table]
      },
      summer_holiday_electricity_analysis: {
        benchmark_class: BenchmarkContentSummerHolidayBaseloadAnalysis,
        name:     'Reduction in baseload in the summer holidays',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String },
          { data: ->{ shol_ann£ },  name: 'Annualised £ value of summer holiday reduction',    units: :£, chart_data: true },
          { data: ->{ shol_hol£ },  name: 'Saving during summer holiday from baseload reduction',  units: :£ },
          { data: ->{ shol_kwrd },  name: 'Reduction in baseload over summer holidays', units: :kw },
          { data: ->{ shol_rrat },  name: 'Size of reduction rating',  units: Float },
          { data: ->{ shol_trat },  name: 'Rating based on number of recent years with reduction',  units: Float },
          { data: ->{ shol_ratg },  name: 'Overall rating',  units: Float },
        ],
        analytics_user_type: true,
        sort_by: [1],
        type: %i[table]
      },
      electricity_peak_kw_per_pupil: {
        benchmark_class: BenchmarkContentPeakElectricityPerFloorArea,
        name:     'Peak school day electricity comparison kW/floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String, chart_data: true, content_class: AdviceElectricityIntraday },
          { data: ->{ epkb_kwfa * 1000.0 },  name: 'w/floor area',    units: :w, chart_data: true },
          { data: ->{ epkb_kwsc },  name: 'average peak kw',  units: :kw },
          { data: ->{ epkb_kwex },  name: 'exemplar peak kw', units: :kw },
          { data: ->{ epkb_tex£ },  name: 'saving if match exemplar (£)', units: :£ },
          { data: ->{ epkb_ratg },  name: 'rating', units: Float, y2_axis: true }
        ],
        where:   ->{ !epkb_kwfa.nil? },
        sort_by: [1],
        type: %i[table chart]
      },
      solar_pv_benefit_estimate: {
        benchmark_class: BenchmarkContentSolarPVBenefit,
        name:     'Benefit of estimated optimum size solar PV installation',
        columns:  [
          { data: 'addp_name',      name: 'School name',      units: String, content_class: AdviceSolarPV  },
          { data: ->{ sole_opvk },  name: 'Size: kWp',    units: :kwp},
          { data: ->{ sole_opvy },  name: 'payback (years)',  units: :years },
          { data: ->{ sole_opvp },  name: 'Reduction in mains consumption (%)', units: :percent }
        ],
        sort_by: [1],
        type: %i[table]
      },
      annual_heating_costs_per_floor_area: {
        benchmark_class:  BenchmarkContentHeatingPerFloorArea,
        name:     'Annual heating cost per floor area',
        columns:  [
          { data: 'addp_name',      name: 'School name',    units: String, chart_data: true, content_class: AdviceGasAnnual },
          { data: ->{ sum_data([gsba_n£m2, shan_n£m2], true) },  name: 'Annual heating costs per floor area', units: :£, chart_data: true },
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr], true) },  name: 'Annual cost £', units: :£},
          { data: ->{ sum_data([gsba_s£ex, shan_s£ex], true) },  name: 'Saving if matched exemplar school', units: :£ },
          { data: ->{ sum_data([gsba_klyr, shan_klyr], true) },  name: 'Annual consumption kWh', units: :kwh},
          { data: ->{ sum_data([gsba_co2y, shan_co2y], true) / 1000.0 },  name: 'Annual carbon emissions (tonnes CO2)', units: :co2},
          { data: ->{ or_nil([gsba_ratg, shan_ratg]) },  name: 'rating', units: Float, y2_axis: true }
        ],
        where:   ->{ !gsba_co2y.nil? },
        sort_by:  [1],
        type: %i[chart table]
      },
      change_in_annual_heating_consumption: {
        benchmark_class:  BenchmarkContentChangeInAnnualHeatingConsumption,
        name:     'Change in annual heating consumption',
        columns:  [
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true, content_class: AdviceGasAnnual },
          { data: ->{ percent_change([gsba_£pyr, shan_£pyr], [gsba_£lyr, shan_£lyr], true) },  name: 'Change in annual gas/storage heater usage', units: :relative_percent_0dp, sense: :positive_is_bad, chart_data: true },
          { data: ->{ gsba_£lyr },  name: 'Annual gas costs £ (this year)', units: :£},
          { data: ->{ gsba_£pyr },  name: 'Annual gas costs £ (last year)', units: :£},
          { data: ->{ shan_£lyr },  name: 'Annual storage heater costs £ (this year)', units: :£},
          { data: ->{ shan_£pyr},  name: 'Annual storage heater costs £ (last year)', units: :£},
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr]) - sum_data([gsba_£pyr, shan_£pyr]) },  name: 'Change in heating costs between last 2 years', units: :£}
        ],
        sort_by:  [1], # column 1 i.e. Annual kWh
        treat_as_nil:   [0],
        type: %i[chart table]
      },
      annual_gas_out_of_hours_use: {
        benchmark_class: BenchmarkContentGasOutOfHoursUsage,
        name:     'Gas: out of hours use',
        columns:  [
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true, content_class: AdviceGasOutHours },
          { data: ->{ gsoo_sdop },  name: 'School Day Open',              units: :percent, chart_data: true },
          { data: ->{ gsoo_sdcp },  name: 'School Day Closed',            units: :percent, chart_data: true },
          { data: ->{ gsoo_holp },  name: 'Holiday',                      units: :percent, chart_data: true },
          { data: ->{ gsoo_wkep },  name: 'Weekend',                      units: :percent, chart_data: true },
          { data: ->{ gsoo_comp },  name: 'Community',                    units: :percent, chart_data: true },
          { data: ->{ gsoo_com£ },  name: 'Community usage cost',         units: :£ },
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
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true, content_class: AdviceStorageHeaters },
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
          { data: 'addp_name',      name: 'School name',                  units: String,   chart_data: true, content_class: AdviceGasBoilerMorningStart },
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
=begin
      length_of_school_day_heating_season_deprecated: {
        benchmark_class:  BenchmarkContentLengthOfHeatingSeasonDeprecated,
        name:     'Number of days heating was on last year',
        columns:  [
          { data: 'addp_name',                   name: 'School name',           units: String, chart_data: true, content_class: AdviceGasBoilerSeasonalControl },
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
=end
      heating_in_warm_weather: {
        benchmark_class:  BenchmarkContentHeatingInWarmWeather,
        name:     'Gas or storage heater consumption for heating in warm weather',
        columns:  [
          { data: 'addp_name',      name: 'School name',           units: String, chart_data: true, content_class: AdviceGasBoilerSeasonalControl },
          { data: ->{ or_nil([shsd_wpan, shsh_wpan]) },  name: 'Percentage of annual heating consumed in warm weather', units: :percent, chart_data: true },
          { data: ->{ or_nil([shsd_wkwh, shsh_wkwh]) },  name: 'Saving through turning heating off in warm weather (kWh)', units: :kwh },
          { data: ->{ or_nil([shsd_wco2, shsh_wco2]) },  name: 'Saving CO2 kg', units: :co2 },
          { data: ->{ or_nil([shsd_w£__, shsh_w£__]) },  name: 'Saving £', units: :£ },
          { data: ->{ or_nil([shsd_wdys, shsh_wdys]) },  name: 'Number of days heating on in warm weather', units: :days },
          { data: ->{ or_nil([shsd_ratg, shsh_ratg]) },  name: 'rating', units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[chart table]
      },
      thermostatic_control: {
        benchmark_class:  BenchmarkContentThermostaticControl,
        name:     'Quality of thermostatic control',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true, content_class: AdviceGasThermostaticControl },
          { data: ->{ or_nil([httc_r2, shtc_r2]) },    name: 'Thermostatic R2', units: :r2,  chart_data: true },
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
          { data: 'addp_name',      name: 'School name', units: String, chart_data: true, content_class: AdviceGasHotWater },
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
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
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
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
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
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
        type: %i[table chart]
      },
      change_in_electricity_consumption_recent_school_weeks: {
        benchmark_class:  BenchmarkContentChangeInElectricityConsumptionSinceLastSchoolWeek,
        name:     'Change in electricity consumption since last school week',
        columns:  [
          { data: ->{ referenced(addp_name, eswc_pnch) }, name: 'School name', units: String, chart_data: true, column_id: :school_name },
          { data: ->{ eswc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ eswc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ eswc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ eswc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ eswc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_electricity_holiday_consumption_previous_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetweenLast2Holidays,
        name:     'Change in electricity consumption between the 2 most recent holidays',
        columns:  [
          { data: ->{ referenced(addp_name, ephc_pnch) }, name: 'School name',     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ ephc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ ephc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ ephc_cper },  name: 'Most recent holiday', units: String },
          { data: ->{ ephc_pper },  name: 'Previous holiday', units: String },
          { data: ->{ ephc_ratg },  name: 'rating', units: Float, y2_axis: true },
          { data: ->{ ephc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ ephc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ ephc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_electricity_holiday_consumption_previous_years_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetween2HolidaysYearApart,
        name:     'Change in electricity consumption between this holiday and the same holiday the previous year',
        columns:  [
          { data: ->{ referenced(addp_name, epyc_pnch) }, name: 'School name',     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ epyc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ epyc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ epyc_cper },  name: 'Most recent holiday', units: String },
          { data: ->{ epyc_pper },  name: 'Previous holiday', units: String },
          { data: ->{ epyc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ epyc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ epyc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
          { data: ->{ epyc_ratg },  name: 'rating', units: Float, y2_axis: true },
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      electricity_consumption_during_holiday: {
        benchmark_class: BenchmarkElectricityOnDuringHoliday,
        name:     'Electricity consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ edhl_£pro },  name: 'Projected usage by end of holiday', units: :£, chart_data: true },
          { data: ->{ edhl_£sfr },  name: 'Holiday usage to date', units: :£ },
          { data: ->{ edhl_hnam },  name: 'Holiday', units: String }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_gas_consumption_recent_school_weeks: {
        benchmark_class: BenchmarkContentChangeInGasConsumptionSinceLastSchoolWeek,
        name:     'Change in gas consumption since last school week',
        columns:  [
          { data: ->{ referenced(addp_name, gswc_pnch) }, name: 'School name',     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gswc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ gswc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gswc_ratg },  name: 'rating', units: Float, y2_axis: true },
          { data: ->{ gswc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :floor_area_changed},
          { data: ->{ gswc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :current_floor_area},
          { data: ->{ gswc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :previous_floor_area}
        ],
        max_x_value:   100,
        sort_by: [1],
        type: %i[table chart]
      },
      change_in_gas_holiday_consumption_previous_holiday: {
        benchmark_class: BenchmarkContentChangeInGasBetweenLast2Holidays,
        name:     'Change in gas consumption between the 2 most recent holidays',
        columns:  [
          { data: ->{ referenced(addp_name, gphc_pnch) }, name: 'School name', units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gphc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ gphc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gphc_cper },  name: 'Most recent holiday', units: String },
          { data: ->{ gphc_pper },  name: 'Previous holiday', units: String },
          { data: ->{ gphc_ratg },  name: 'rating', units: Float, y2_axis: true },
          { data: ->{ gswc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :floor_area_changed},
          { data: ->{ gswc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :current_floor_area},
          { data: ->{ gswc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :previous_floor_area}
        ],
        sort_by: [1],
        max_x_value:   100,
        # min_x_value:  -5,
        type: %i[table chart]
      },
      change_in_gas_holiday_consumption_previous_years_holiday: {
        benchmark_class: BenchmarkContentChangeInGasBetween2HolidaysYearApart,
        name:     'Change in gas consumption between this holiday and the same the previous year',
        columns:  [
          { data: ->{ referenced(addp_name, gpyc_pnch) }, name: 'School name', units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gpyc_difp },  name: 'Change %', units: :relative_percent_0dp, chart_data: true },
          { data: ->{ gpyc_dif£ },  name: 'Change £', units: :£ },
          { data: ->{ gpyc_cper },  name: 'Most recent holiday', units: String },
          { data: ->{ gpyc_pper },  name: 'Previous holiday', units: String },
          { data: ->{ gpyc_ratg },  name: 'rating', units: Float, y2_axis: true },
          { data: ->{ gpyc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :floor_area_changed},
          { data: ->{ gpyc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :current_floor_area},
          { data: ->{ gpyc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :previous_floor_area},
        ],
        max_x_value:   100,
        sort_by: [1],
        type: %i[table chart]
      },
      gas_consumption_during_holiday: {
        benchmark_class: BenchmarkGasHeatingHotWaterOnDuringHoliday,
        name:     'Gas consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ hdhl_£pro },  name: 'Projected usage by end of holiday', units: :£, chart_data: true },
          { data: ->{ hdhl_£sfr },  name: 'Holiday usage to date', units: :£ },
          { data: ->{ hdhl_hnam },  name: 'Holiday', units: String }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      storage_heater_consumption_during_holiday: {
        benchmark_class: BenchmarkStorageHeatersOnDuringHoliday,
        name:     'Storage heater consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: 'School name',     units: String, chart_data: true },
          { data: ->{ shoh_£pro },  name: 'Projected usage by end of holiday', units: :£, chart_data: true },
          { data: ->{ shoh_£sfr },  name: 'Holiday usage to date', units: :£ },
          { data: ->{ shoh_hnam },  name: 'Holiday', units: String }
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      holiday_usage_last_year:  {
        benchmark_class: BenchmarkEnergyConsumptionInUpcomingHolidayLastYear,
        name:     'Energy Consumption in upcoming holiday last year',
        columns:  [
          { data: 'addp_name',      name: 'School name',                units: String, chart_data: true },
          { data: ->{ ihol_glyr },  name: 'Gas',                        units: :£, chart_data: true  },
          { data: ->{ ihol_elyr },  name: 'Electricity',                units: :£, chart_data: true },
          { data: ->{ ihol_gpfa },  name: 'Gas kWh per floor area',     units: :kwh },
          { data: ->{ ihol_epup },  name: 'Electricity kWh per pupil',  units: :kwh },
          { data: ->{ ihol_pper },  name: 'Holiday',                    units: String },
        ],
        sort_by: [1],
        type: %i[table chart]
      },
      school_information: {
        benchmark_class:  nil,
        filter_out:     :dont_make_available_directly,
        name:     'School information - used for drilldown, not directly presented to user',
        columns:  [
          # the ordered and index of these 3 columns is important as hardcoded
          # indexes are used else where in the code [0] etc. to map between id and urn
          # def school_map()
          { data: 'addp_name',     name: 'School name', units: String,  chart_data: false },
          { data: 'addp_urn',      name: 'URN',         units: Integer, chart_data: false },
          { data: ->{ school_id }, name: 'school id',   units: Integer, chart_data: false  }
        ],
        sort_by: [1],
        type: %i[table]
      },
    }.freeze
  end
end
