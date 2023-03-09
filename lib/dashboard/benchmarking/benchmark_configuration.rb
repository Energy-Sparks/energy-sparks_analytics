require_relative './benchmark_content_base.rb'
require_relative './benchmark_content_general.rb'
require_relative '../charting_and_reports/tables/management_summary_table.rb'

module Benchmarking

  class BenchmarkManager

    COLUMN_HEADINGS = {
      :annualised_£_value_of_summer_holiday_reduction => "Annualised £ value of summer holiday reduction",
                                 :average_baseload_kw => "Average baseload kW",
                       :average_baseload_last_week_kw => "Average baseload last week (kW)",
                       :average_baseload_last_year_kw => "Average baseload last year (kW)",
                :average_heating_start_time_last_week => "Average heating start time last week",
                :average_heating_start_time_last_year => "Average heating start time last year",
                                     :average_peak_kw => "Average peak kw",
                                :baseload_per_pupil_w => "Baseload per pupil (W)",
                                    :baseload_percent => "Baseload as a percent of total usage",
                                :blended_current_rate => :blended_current_rate,
                                       :co2_last_year => "CO2 (last year)",
                                   :co2_previous_year => "CO2 (previous year)",
                                              :change => "Change",
                                          :change_pct => "Change %",
                              :change_excluding_solar => "Change (excluding solar)",
                                :change_in_annual_co2 => "Change in annual CO2",
    :change_in_annual_electricity_co2_excluding_solar => "Change in annual electricity CO2 (excluding solar)",
                  :change_in_annual_electricity_usage => "Change in annual electricity usage",
                            :change_in_annual_gas_co2 => "Change in annual gas CO2",
           :change_in_annual_gas_storage_heater_usage => "Change in annual gas/storage heater usage",
                       :change_in_annual_solar_pv_co2 => "Change in annual solar PV CO2",
                 :change_in_annual_storage_heater_co2 => "Change in annual storage heater CO2",
             :change_in_baseload_last_week_v_year_pct => "Change in baseload last week v. year (%)",
              :change_in_baseload_last_week_v_year_kw => "Change in baseload last week v. year (kW)",
        :change_in_heating_costs_between_last_2_years => "Change in heating costs between last 2 years",
                                            :change_£ => "Change £",
                                     :change_£current => "Change £ (latest tariff)",
                                          :change_kwh => "Change kWh",
                                             :colder? => "Colder?",
                                           :community => "Community",
                                :community_usage_cost => "Community usage cost",
                          :cost_of_change_in_baseload => 'Next year cost of change in baseload',
                                      :cost_per_pupil => "Cost per pupil",
                   :day_of_week_with_maximum_baseload => "Day of week with maximum baseload",
                   :day_of_week_with_minimum_baseload => "Day of week with minimum baseload",
                                :efficiency_of_system => "Efficiency of system",
                                         :electricity => "Electricity",
                                  :electricity_cost_ht => "Electricity cost (historic tariff)",
                                  :electricity_cost_ct => "Electricity cost (current tariff)",
                           :electricity_co2_last_year => "Electricity CO2 (last year)",
                       :electricity_co2_previous_year => "Electricity CO2 (previous year)",
                           :electricity_kwh_per_pupil => "Electricity kWh per pupil per holiday",
                                        :energy_total => "Energy (total)",
                             :energy_sparks_join_date => "Energy Sparks join date",
               :estimate_of_annual_refrigeration_cost => "Estimate of annual refrigeration cost",
                                           :estimated => "Estimated",
                                    :exemplar_peak_kw => "Exemplar peak kw",
                                          :floor_area => "Floor area",
                                                :fuel => "Fuel",
                                                 :gas => "Gas",
                                         :gas_cost_ht => "Gas cost (historic tariff)",
                                         :gas_cost_ct => "Gas cost (current tariff)",
                                   :gas_co2_last_year => "Gas CO2 (last year)",
                               :gas_co2_previous_year => "Gas CO2 (previous year)",
                              :gas_kwh_per_floor_area => "Gas kWh per floor area per holiday",
                                             :holiday => "Holiday",
                               :holiday_usage_to_date => "Holiday usage to date",
                                           :last_year => "Last year",
                             :last_year_electricity_£ => "Last year electricity £",
                          :last_year_electricity_£_ct => "Last year electricity £ at current tariff",
                          :last_year_energy_co2tonnes => "Last year Energy CO2(tonnes)",
                                :last_year_energy_kwh => "Last year Energy kWh",
                                     :last_year_gas_£ => "Last year Gas £",
                          :last_year_storage_heater_£ => "Last year Storage Heater £",
               :last_year_carbon_emissions_tonnes_co2 => "Last year carbon emissions (tonnes CO2)",
                           :last_year_consumption_kwh => "Last year consumption kWh",
                          :last_year_cost_of_baseload => "Last year cost of baseload",
                                    :last_year_cost_£ => "Last year cost £",
                       :last_year_electricity_£_pupil => "Last year electricity £/pupil",
                    :last_year_electricity_£_pupil_ct => "Last year electricity £/pupil at current tariff",
                     :last_year_electricity_kwh_pupil => "Last year electricity kWh/pupil",
                             :last_year_energy_cost_£ => "Last year energy cost £",
                       :last_year_energy_£_floor_area => "Last year energy £/floor area",
                            :last_year_energy_£_pupil => "Last year energy £/pupil",
                          :last_year_energy_kwh_pupil => "Last year energy kWh/pupil",
                        :last_year_energy_kgco2_pupil => "Last year energy kgCO2/pupil",
                               :last_year_gas_costs_£ => "Last year gas costs",
                             :last_year_gas_kwh_pupil => "Last year gas kWh/pupil",
              :last_year_heating_costs_per_floor_area => "Last year heating costs per floor area",
                           :last_year_kwh_consumption => "Last year kWh consumption",
                         :last_year_out_of_hours_cost => "Last year out of hours cost",
             :last_year_saving_if_improve_to_exemplar => "Last year saving if improve to exemplar",
     :last_year_saving_per_1c_reduction_in_thermostat => "Saving per 1C reduction in thermostat",
                    :last_year_storage_heater_costs_£ => "Last year storage heater costs",
                  :last_year_storage_heater_kwh_pupil => "Last year storage heater  kWh/pupil",
                 :last_year_weekend_and_holiday_costs => "Last year weekend and holiday costs",
                     :max_average_weekday_baseload_kw => "Max average weekday baseload kW",
                                            :metering => "Metering",
                     :min_average_weekday_baseload_kw => "Min average weekday baseload kW",
                                 :most_recent_holiday => "Most recent holiday",
                                                :name => "School",        
                                      :no_recent_data => "No recent data",
           :number_of_days_heating_on_in_warm_weather => "Number of days heating on in warm weather",
                        :number_of_electricity_meters => "Number of electricity meters",
                                :number_of_gas_meters => "Number of gas meters",
                                :optimum_start_rating => "Optimum start rating",
                                      :overall_change => "Overall change",
                                      :overall_rating => "Overall rating",
                                  :overnight_charging => "Overnight charging",
                                       :payback_years => "Payback (years)",
                    :percent_above_or_below_last_year => "Percent above or below last year",
      :percent_above_or_below_target_since_target_set => "Percent above or below target since target set",
     :percent_increase_on_winter_baseload_over_summer => "Percent increase on winter baseload over summer",
:percentage_of_annual_heating_consumed_in_warm_weather => "Percentage of annual heating consumed in warm weather",
                           :potential_annual_saving_£ => "Potential annual saving £",
                       :potential_max_annual_saving_£ => "Potential max annual saving £",
                                    :potential_saving => "Potential saving (at latest tariff)",
                                    :previous_holiday => "Previous holiday",
                                       :previous_year => "Previous year",
                  :previous_year_temperature_adjusted => "Previous year (temperature adjusted)",
                :previous_year_temperature_unadjusted => "Previous year (temperature unadjusted)",
                         :previous_year_electricity_£ => "Previous year electricity £",
                           :previous_year_gas_costs_£ => "Previous year gas costs",
                :previous_year_storage_heater_costs_£ => "Previous year storage heater costs",
                   :projected_usage_by_end_of_holiday => "Projected usage by end of holiday",
                                              :pupils => "Pupils",
                                              :rating => "rating",
:rating_based_on_number_of_recent_years_with_reduction => "Rating based on number of recent years with reduction",
          :reduction_in_baseload_over_summer_holidays => "Reduction in baseload over summer holidays",
                 :reduction_in_kw_over_summer_holiday => "Reduction in kW over summer holiday",
                  :reduction_in_mains_consumption_pct => "Reduction in mains consumption (%)",
                   :regression_model_optimum_start_r2 => "Regression model optimum start r2",
:regression_model_optimum_start_sensitivity_to_outside_temperature => "Regression model optimum start sensitivity to outside temperature",
                 :regression_model_optimum_start_time => "Regression model optimum start time",
                                       :saving_co2_kg => "Saving CO2 kg",
:saving_during_summer_holiday_from_baseload_reduction => "Saving during summer holiday from baseload reduction",
                       :saving_if_improve_to_exemplar => "Saving if improve to exemplar (at latest tariff)",
                          :saving_if_match_exemplar_£ => "Saving if match exemplar (£ at latest tariff)",
                   :saving_if_matched_exemplar_school => "Saving if matched exemplar school (using latest tariff)",
                         :saving_if_moved_to_exemplar => "Saving if moved to exemplar (at latest tariff)",
                      :saving_if_same_all_year_around => "Saving if same all year around (at latest tariff)",
                             :saving_improving_timing => "Saving improving timing",
                               :saving_optimal_panels => "Annual saving at latest tariff if optimal panel size installed",
                          :saving_over_summer_holiday => "Saving over summer holiday",
        :saving_through_improved_thermostatic_control => "Saving through improved thermostatic control",
:saving_through_turning_heating_off_in_warm_weather_kwh => "Saving through turning heating off in warm weather (kWh)",
                  :saving_with_pou_electric_hot_water => "Saving with POU electric hot water",
                                            :saving_£ => "Saving £",
                                   :school_day_closed => "School Day Closed",
                                     :school_day_open => "School Day Open",
                                           :school_id => "School id",
                                         :school_name => "School name",
                            :size_of_reduction_rating => "Size of reduction rating",
                                            :size_kwp => "Size: kWp",
                                            :solar_pv => "Solar PV",
                              :solar_pv_co2_last_year => "Solar PV CO2 (last year)",
                          :solar_pv_co2_previous_year => "Solar PV CO2 (previous year)",
  :standard_deviation_of_start_time__hours_last_year => "Standard deviation of start time - hours, last year",
                               :start_date_for_target => "Start date for target",
                        :storage_heater_co2_last_year => "Storage Heater CO2 (last year)",
                    :storage_heater_co2_previous_year => "Storage Heater CO2 (previous year)",
                                     :storage_heaters => "Storage heaters",
                                  :summer_baseload_kw => "Summer baseload kW",
                              :target_kwh_consumption => "Target kWh consumption",
                                :temperature_adjusted => "Temperature adjusted",
                              :temperature_unadjusted => "Temperature unadjusted",
                            :temperature_adjusted_kwh => "Temperature adjusted change (kWh)",
                                     :thermostatic_r2 => "Thermostatic R2",
                                :total_energy_costs_£ => "Total Energy Costs £",
                                                :type => "Type",
                                                 :urn => "URN",
                                          :unadjusted => "Unadjusted",
                                      :unadjusted_kwh => "Unadjusted change (kWh)",
          :variation_in_baseload_between_days_of_week => "Variation in baseload between days of week",
                                             :weekend => "Weekend",
                                  :winter_baseload_kw => "Winter baseload kW",
                                  :year_before_joined => "Year before joined",
                    :kwh_consumption_since_target_set => "kWh consumption since target set",
                                      :tariff_changed => :tariff_changed,
                               :tariff_changed_period => :tariff_changed_period,
                                        :w_floor_area => "w/floor area"
    }.freeze

    def self.ch(key)
      if COLUMN_HEADINGS.key?(key)
        COLUMN_HEADINGS[key]
      else
        raise EnergySparksUnexpectedStateException, "Unexpected key #{key} #{key.class.name} for benchmark column heading"
      end
    end

    def self.column_headings_refer_to(column_heading, key)
      return nil if column_heading.nil?

      column_heading.to_s.downcase.include?(COLUMN_HEADINGS[key].to_s.downcase)
    end

    def self.column_heading_refers_to_last_year?(column_heading)
      column_headings_refer_to(column_heading, :last_year)
    end

    def self.column_heading_refers_to_previous_year?(column_heading)
      column_headings_refer_to(column_heading, :previous_year)
    end

    def self.chart_table_config(name)
      CHART_TABLE_CONFIG[name]
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

    def self.structured_pages(user_type_hash = { user_role: :guest }, _filter_out = nil)
      user_role = user_type_hash[:user_role] || :guest

      CHART_TABLE_GROUPING.each_with_object([]) do |(group_key, benchmark_keys), structured_pages|
        structured_page = structured_page_for(group_key, benchmark_keys, user_role)
        next unless structured_page
        structured_pages << structured_page
      end
    end

    def self.structured_page_for(group_key, benchmark_keys, user_role)
      benchmarks = benchmark_titles_for(benchmark_keys, user_role)
      return if benchmarks.empty?

      {
        name: I18n.t("analytics.benchmarking.chart_table_grouping.#{group_key}.title"),
        description: I18n.t("analytics.benchmarking.chart_table_grouping.#{group_key}.description"),
        benchmarks: benchmark_titles_for(benchmark_keys, user_role)
      }
    end

    def self.benchmark_titles_for(benchmark_keys, user_role)
      benchmark_keys.each_with_object({}) do |benchmark_key, benchmarks|
        next if CHART_TABLE_CONFIG[benchmark_key][:admin_only] == true && [:admin, :analyst].exclude?(user_role)

        benchmarks[benchmark_key] = I18n.t("analytics.benchmarking.chart_table_config.#{benchmark_key}")
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

    CHART_TABLE_GROUPING = {
      total_energy_use_benchmarks: [
        :annual_energy_costs_per_pupil,
        :annual_energy_costs,
        :annual_energy_costs_per_floor_area,
        :change_in_energy_since_last_year,
        :holiday_usage_last_year
      ],
      electricity_benchmarks: [
        :change_in_electricity_since_last_year,
        :annual_electricity_costs_per_pupil,
        :annual_electricity_out_of_hours_use,
        :recent_change_in_baseload,
        :baseload_per_pupil,
        :seasonal_baseload_variation,
        :weekday_baseload_variation,
        :electricity_peak_kw_per_pupil,
        :electricity_targets,
        :change_in_electricity_consumption_recent_school_weeks,
        :change_in_electricity_holiday_consumption_previous_holiday,
        :change_in_electricity_holiday_consumption_previous_years_holiday,
        :electricity_consumption_during_holiday
      ],
      gas_and_storage_heater_benchmarks: [
        :change_in_gas_since_last_year,
        :change_in_storage_heaters_since_last_year,
        :annual_heating_costs_per_floor_area,
        :annual_gas_out_of_hours_use,
        :annual_storage_heater_out_of_hours_use,
        :heating_coming_on_too_early,
        :thermostat_sensitivity,
        :heating_in_warm_weather,
        :thermostatic_control,
        :hot_water_efficiency,
        :gas_targets,
        :change_in_gas_consumption_recent_school_weeks,
        :change_in_gas_holiday_consumption_previous_holiday,
        :change_in_gas_holiday_consumption_previous_years_holiday,
        :gas_consumption_during_holiday,
        :storage_heater_consumption_during_holiday
      ],
      solar_benchmarks: [
        :change_in_solar_pv_since_last_year,
        :solar_pv_benefit_estimate
      ],
      date_limited_comparisons: [
        :layer_up_powerdown_day_november_2022,
        :change_in_energy_use_since_joined_energy_sparks,
        :autumn_term_2021_2022_energy_comparison,
        :sept_nov_2021_2022_energy_comparison
      ]
    }

    def self.tariff_changed_school_name(content_class = nil)
      if content_class.nil?
        { data: ->{ tariff_change_reference(addp_name, addp_etch || addp_gtch)}, name: ch(:name), units: String, chart_data: true }
      else
        { data: ->{ tariff_change_reference(addp_name, addp_etch || addp_gtch)}, name: ch(:name), units: String, chart_data: true, content_class: content_class }
      end
    end

    def self.tariff_changed_between_periods(changed)
      { data: changed, name: ch(:tariff_changed_period), units: TrueClass, hidden: true }
    end

    TARIFF_CHANGED_COL        = { data: ->{ addp_etch || addp_gtch }, name: ch(:tariff_changed), units: TrueClass, hidden: true }

    def self.blended_baseload_rate_col(variable)
      { data: variable, name: ch(:blended_current_rate), units: :£_per_kwh, hidden: true }
    end

    CHART_TABLE_CONFIG = {
      annual_energy_costs_per_pupil: {
        benchmark_class:  BenchmarkContentEnergyPerPupil,
        name:     'Annual energy use per pupil',
        columns:  [
          tariff_changed_school_name(AdviceBenchmark),
          { data: ->{ elba_kpup },          name: ch(:last_year_electricity_kwh_pupil), units: :kwh, chart_data: true },
          { data: ->{ gsba_kpup },          name: ch(:last_year_gas_kwh_pupil), units: :kwh, chart_data: true },
          { data: ->{ shan_kpup },          name: ch(:last_year_storage_heater_kwh_pupil), units: :kwh, chart_data: true },
          { data: ->{ sum_data([elba_kpup, gsba_kpup, shan_kpup]) }, name: ch(:last_year_energy_kwh_pupil), units: :kwh},
          { data: ->{ sum_data([elba_£pup, gsba_£pup, shan_£pup]) }, name: ch(:last_year_energy_£_pupil), units: :£},
          { data: ->{ sum_data([elba_cpup, gsba_cpup, shan_cpup]) }, name: ch(:last_year_energy_kgco2_pupil), units: :kwh},
          { data: ->{ addp_stpn },          name: ch(:type),   units: String },
          { data: ->{ enba_ratg },          name: ch(:rating), units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !enba_kpup.nil? },
        sort_by:  method(:sort_energy_costs),
        type: %i[chart table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark },
        admin_only: false
      },
      annual_energy_costs: {
        benchmark_class:  BenchmarkContentTotalAnnualEnergy,
        name:     'Annual energy costs',
        columns:  [
          { data: 'addp_name',              name: ch(:name), units: String, chart_data: true },
          { data: ->{ elba_£lyr },          name: ch(:last_year_electricity_£), units: :£, chart_data: true },
          { data: ->{ gsba_£lyr },          name: ch(:last_year_gas_£), units: :£, chart_data: true },
          { data: ->{ shan_£lyr },          name: ch(:last_year_storage_heater_£), units: :£, chart_data: true },
          { data: ->{ enba_£lyr },          name: ch(:total_energy_costs_£), units: :£},
          { data: ->{ enba_£pup },          name: ch(:last_year_energy_£_pupil), units: :£},
          { data: ->{ enba_co2t },          name: ch(:last_year_energy_co2tonnes), units: :co2 },
          { data: ->{ enba_klyr },          name: ch(:last_year_energy_kwh), units: :kwh },
          { data: ->{ addp_stpn },          name: ch(:type),   units: String  },
          { data: ->{ addp_pupn },          name: ch(:pupils), units: :pupils },
          { data: ->{ addp_flra },          name: ch(:floor_area), units: :m2 },
        ],
        sort_by:  [4],
        type: %i[chart table],
        admin_only: false
      },
      annual_energy_costs_per_floor_area: {
        benchmark_class:  BenchmarkContentEnergyPerFloorArea,
        name:     'Annual energy use per floor area',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true },
          { data: ->{ enba_£fla },  name: ch(:last_year_energy_£_floor_area), units: :£, chart_data: true },
          { data: ->{ enba_£lyr },  name: ch(:last_year_energy_cost_£), units: :£},
          { data: ->{ enba_ratg },  name: ch(:rating), units: Float, y2_axis: true },
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      change_in_energy_use_since_joined_energy_sparks: {
        benchmark_class:  BenchmarkContentChangeInEnergyUseSinceJoined,
        name:     'Change in energy use since the school joined Energy Sparks',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: :short_school_name, chart_data: true },
          { data: ->{ enba_sact },  name: ch(:energy_sparks_join_date), units: :date_mmm_yyyy },
          { data: ->{ enba_kxap },  name: ch(:energy_total),   units: :relative_percent_0dp, chart_data: true, content_class: AdviceBenchmark },
          { data: ->{ enba_keap },  name: ch(:electricity),      units: :relative_percent_0dp },
          { data: ->{ enba_kgap },  name: ch(:gas),              units: :relative_percent_0dp },
          { data: ->{ enba_khap },  name: ch(:storage_heaters),  units: :relative_percent_0dp },
          { data: ->{ enba_ksap },  name: ch(:solar_pv),         units: :relative_percent_0dp }
        ],
        column_groups: [
          { name: '',                                     span: 2 },
          { name: 'Change since joined Energy Sparks',    span: 5 },
        ],
        treat_as_nil:   [ManagementSummaryTable::NO_RECENT_DATA_MESSAGE, ManagementSummaryTable::NOT_ENOUGH_DATA_MESSAGE], # from ManagementSummaryTable:: not referenced because not on path
        sort_by:  [2],
        type: %i[chart table],
        admin_only: true
      },
      # second chart and table on page defined by change_in_energy_use_since_joined_energy_sparks above
      # not displayed on its own as a separate comparison
      change_in_energy_use_since_joined_energy_sparks_full_data: {
        benchmark_class:  BenchmarkContentChangeInEnergyUseSinceJoinedFullData,
        filter_out:       :dont_make_available_directly,
        name:     'breakdown in the change in energy use since the school joined Energy Sparks',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: :short_school_name, chart_data: true },
          { data: ->{ enba_sact },  name: ch(:energy_sparks_join_date), units: :date_mmm_yyyy },

          { data: ->{ enba_kea }, name: ch(:year_before_joined),       units: :kwh },
          { data: ->{ enba_ke0 }, name: ch(:last_year),                units: :kwh },
          { data: ->{ enba_keap}, name: ch(:change_excluding_solar), units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kga }, name: ch(:year_before_joined), units: :kwh },
          { data: ->{ enba_kg0 }, name: ch(:last_year),          units: :kwh },
          { data: ->{ enba_kgap}, name: ch(:change),             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kha }, name: ch(:year_before_joined), units: :kwh },
          { data: ->{ enba_kh0 }, name: ch(:last_year),          units: :kwh },
          { data: ->{ enba_khap}, name: ch(:change),             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_ksa }, name: ch(:year_before_joined), units: :kwh },
          { data: ->{ enba_ks0 }, name: ch(:last_year),          units: :kwh },
          { data: ->{ enba_ksap}, name: ch(:change),             units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_kxap },  name: ch(:change),           units: :relative_percent_0dp, y2_axis: true }
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
        type: %i[chart table],
        admin_only: true
      },
      change_in_co2_emissions_since_last_year: {
        benchmark_class:  BenchmarkContentChangeInCO2SinceLastYear,
        name:     'Change in annual CO2 emissions since last year',
        columns:  [
          { data: 'addp_name',      name: ch(:name),          units: String, chart_data: true },
          { data: ->{ enba_cxn },   name: ch(:co2_previous_year),  units: :co2 },
          { data: ->{ enba_cx0 },   name: ch(:co2_last_year),      units: :co2 },
          { data: ->{ enba_cxnp},   name: ch(:change_in_annual_co2), units: :relative_percent_0dp, chart_data: true }
        ],
        sort_by:  [3],
        type: %i[chart table],
        admin_only: true
      },
      # second chart and table on page defined by change_in_co2_emissions_since_last_year above
      # not displayed on its own as a separate comparison
      change_in_co2_emissions_since_last_year_full_table: {
        benchmark_class:  BenchmarkContentChangeInCO2SinceLastYearFullData,
        filter_out:       :dont_make_available_directly,
        name:     'Breakdown of CO2 emissions change since last year',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true },

          { data: ->{ enba_cen }, name: ch(:electricity_co2_previous_year),                    units: :co2 },
          { data: ->{ enba_ce0 }, name: ch(:electricity_co2_last_year),                        units: :co2 },
          { data: ->{ enba_cenp}, name: ch(:change_in_annual_electricity_co2_excluding_solar), units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_cgn },  name: ch(:gas_co2_previous_year),   units: :co2 },
          { data: ->{ enba_cg0 },  name: ch(:gas_co2_last_year),       units: :co2 },
          { data: ->{ enba_cgnp},  name: ch(:change_in_annual_gas_co2),  units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_chn },  name: ch(:storage_heater_co2_previous_year),  units: :co2 },
          { data: ->{ enba_ch0 },  name: ch(:storage_heater_co2_last_year),      units: :co2 },
          { data: ->{ enba_chnp},  name: ch(:change_in_annual_storage_heater_co2), units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_csn },  name: ch(:solar_pv_co2_previous_year),  units: :co2 },
          { data: ->{ enba_cs0 },  name: ch(:solar_pv_co2_last_year),      units: :co2 },
          { data: ->{ enba_csnp},  name: ch(:change_in_annual_solar_pv_co2), units: :relative_percent_0dp, chart_data: true },

          { data: ->{ enba_cxnp},  name: ch(:overall_change), units: :relative_percent_0dp, y2_axis: true },
        ],
        sort_by:  [13],
        type: %i[chart table],
        admin_only: true
      },
      layer_up_powerdown_day_november_2022: {
        benchmark_class:  BenchmarkChangeAdhocComparison,
        name:       'Change in energy for layer up power down day 11 November 2022 (compared with 12 Nov 2021)',
        columns:  [
          { data: 'addp_name', name: ch(:name), units: :short_school_name, chart_data: true},

          # kWh

          { data: ->{ sum_if_complete([lue1_pppk, lug1_pppk, lus1_pppk], [lue1_cppk, lug1_cppk, lus1_cppk]) }, name: ch(:previous_year), units: :kwh },
          { data: ->{ sum_data([lue1_cppk, lug1_cppk, lus1_cppk]) },                                name: ch(:last_year),  units: :kwh }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([lue1_pppk, lug1_pppk, lus1_pppk], [lue1_cppk, lug1_cppk, lus1_cppk]),
                                      sum_data([lue1_cppk, lug1_cppk, lus1_cppk]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # CO2
          { data: ->{ sum_if_complete([lue1_pppc, lug1_pppc, lus1_pppc], [lue1_cppc, lug1_cppc, lus1_cppc]) }, name: ch(:previous_year), units: :co2 },
          { data: ->{ sum_data([lue1_cppc, lug1_cppc, lus1_cppc]) },                                name: ch(:last_year),  units: :co2 }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([lue1_pppc, lug1_pppc, lus1_pppc], [lue1_cppc, lug1_cppc, lus1_cppc]),
                                      sum_data([lue1_cppc, lug1_cppc, lus1_cppc]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # £

          { data: ->{ sum_if_complete([lue1_ppp£, lug1_ppp£, lus1_ppp£], [lue1_cpp£, lug1_cpp£, lus1_cpp£]) }, name: ch(:previous_year), units: :£ },
          { data: ->{ sum_data([lue1_cpp£, lug1_cpp£, lus1_cpp£]) },                                name: ch(:last_year),  units: :£ }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([lue1_ppp£, lug1_ppp£, lus1_ppp£], [lue1_cpp£, lug1_cpp£, lus1_cpp£]),
                                      sum_data([lue1_cpp£, lug1_cpp£, lus1_cpp£]),
                                      true
                                    ) },
            name: ch(:change_£), units: :relative_percent_0dp, chart_data: true
          },

          # Metering

          { data: ->{
              [
                lue1_ppp£.nil? ? nil : 'Electricity',
                lug1_ppp£.nil? ? nil : 'Gas',
                lus1_ppp£.nil? ? nil : 'Storage Heaters'
              ].compact.join(', ')
            },
            name: ch(:metering),
            units: String
          },
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 },
          { name: '',         span: 1 }
        ],
        where:   ->{ !sum_data([lue1_ppp£, lug1_ppp£, lus1_ppp£], true).nil? },
        sort_by:  [9],
        type: %i[chart table],
        admin_only: true
      },
      layer_up_powerdown_day_november_2022_electricity_table: {
        benchmark_class:  BenchmarkChangeAdhocComparisonElectricityTable,
        filter_out:     :dont_make_available_directly,
        name:       'Change in electricity for layer up power down day November 2022',
        columns:  [
          { data: 'addp_name', name: ch(:name), units: :short_school_name },

          # kWh
          { data: ->{ lue1_pppk }, name: ch(:previous_year), units: :kwh },
          { data: ->{ lue1_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(lue1_pppk, lue1_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ lue1_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ lue1_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(lue1_pppc, lue1_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ lue1_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ lue1_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(lue1_ppp£, lue1_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 4 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !lue1_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      layer_up_powerdown_day_november_2022_gas_table: {
        benchmark_class:  BenchmarkChangeAdhocComparisonGasTable,
        filter_out:     :dont_make_available_directly,
        name:       'Change in gas for layer up power down day November 2022',
        columns:  [
          { data: 'addp_name', name: ch(:name), units: :short_school_name },

          # kWh
          { data: ->{ lug1_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ lug1_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ lug1_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(lug1_pppk, lug1_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ lug1_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ lug1_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(lug1_pppc, lug1_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ lug1_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ lug1_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(lug1_ppp£, lug1_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !lug1_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true        
      },
      layer_up_powerdown_day_november_2022_storage_heater_table: {
        benchmark_class:  BenchmarkChangeAdhocComparisonStorageHeaterTable,
        filter_out:     :dont_make_available_directly,
        name:       'Change in gas for layer up power down day November 2022',
        columns:  [
          { data: 'addp_name', name: ch(:name), units: :short_school_name },

          # kWh
          { data: ->{ lus1_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ lus1_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ lus1_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(lus1_pppk, lus1_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ lus1_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ lus1_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(lus1_pppc, lus1_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ lus1_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ lus1_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(lus1_ppp£, lus1_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !lus1_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true        
      },
      autumn_term_2021_2022_energy_comparison: {
        benchmark_class:  BenchmarkAutumn2022Comparison,
        name:       'Autumn Term 2021 versus 2022 energy use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh

          { data: ->{ sum_if_complete([a22e_pppk, a22g_pppk, a22s_pppk], [a22e_cppk, a22g_cppk, a22s_cppk]) }, name: ch(:previous_year), units: :kwh },
          { data: ->{ sum_data([a22e_cppk, a22g_cppk, a22s_cppk]) },                                name: ch(:last_year),  units: :kwh }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([a22e_pppk, a22g_pppk, a22s_pppk], [a22e_cppk, a22g_cppk, a22s_cppk]),
                                      sum_data([a22e_cppk, a22g_cppk, a22s_cppk]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # CO2
          { data: ->{ sum_if_complete([a22e_pppc, a22g_pppc, a22s_pppc], [a22e_cppc, a22g_cppc, a22s_cppc]) }, name: ch(:previous_year), units: :co2 },
          { data: ->{ sum_data([a22e_cppc, a22g_cppc, a22s_cppc]) },                                name: ch(:last_year),  units: :co2 }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([a22e_pppc, a22g_pppc, a22s_pppc], [a22e_cppc, a22g_cppc, a22s_cppc]),
                                      sum_data([a22e_cppc, a22g_cppc, a22s_cppc]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # £

          { data: ->{ sum_if_complete([a22e_ppp£, a22g_ppp£, a22s_ppp£], [a22e_cpp£, a22g_cpp£, a22s_cpp£]) }, name: ch(:previous_year), units: :£ },
          { data: ->{ sum_data([a22e_cpp£, a22g_cpp£, a22s_cpp£]) },                                name: ch(:last_year),  units: :£ }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([a22e_ppp£, a22g_ppp£, a22s_ppp£], [a22e_cpp£, a22g_cpp£, a22s_cpp£]),
                                      sum_data([a22e_cpp£, a22g_cpp£, a22s_cpp£]),
                                      true
                                    ) },
            name: ch(:change_£), units: :relative_percent_0dp, chart_data: true
          },

          # Metering

          { data: ->{
              [
                a22e_ppp£.nil? ? nil : 'Electricity',
                a22g_ppp£.nil? ? nil : 'Gas',
                a22s_ppp£.nil? ? nil : 'Storage Heaters'
              ].compact.join(', ')
            },
            name: ch(:metering),
            units: String
          },
          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 },
          { name: '',         span: 1 }
        ],
        where:   ->{ !sum_data([a22e_ppp£, a22g_ppp£, a22s_ppp£], true).nil? },
        sort_by:  [9],
        type: %i[chart table],
        admin_only: true
      },
      autumn_term_2021_2022_electricity_table: {
        benchmark_class:  BenchmarkAutumn2022ElectricityTable,
        filter_out:     :dont_make_available_directly,
        name:       'Autumn Term 2021 versus 2022 electricity use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ a22e_pppk }, name: ch(:previous_year), units: :kwh },
          { data: ->{ a22e_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(a22e_pppk, a22e_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ a22e_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ a22e_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(a22e_pppc, a22e_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ a22e_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ a22e_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(a22e_ppp£, a22e_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !a22e_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      autumn_term_2021_2022_gas_table: {
        benchmark_class:  BenchmarkAutumn2022GasTable,
        filter_out:     :dont_make_available_directly,
        name:       'Autumn Term 2021 versus 2022 gas use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ a22g_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ a22g_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ a22g_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(a22g_pppk, a22g_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ a22g_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ a22g_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(a22g_pppc, a22g_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ a22g_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ a22g_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(a22g_ppp£, a22g_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 4 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !a22g_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      autumn_term_2021_2022_storage_heater_table: {
        benchmark_class:  BenchmarkAutumn2022StorageHeaterTable,
        filter_out:     :dont_make_available_directly,
        name:       'Autumn Term 2021 versus 2022 storage heater use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ a22s_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ a22s_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ a22s_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(a22s_pppk, a22s_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ a22s_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ a22s_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(a22s_pppc, a22s_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ a22s_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ a22s_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(a22s_ppp£, a22s_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 4 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !a22s_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      sept_nov_2021_2022_energy_comparison: {
        benchmark_class:  BenchmarkSeptNov2022Comparison,
        name:       'September to November 2021 versus 2022 energy use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh

          { data: ->{ sum_if_complete([s22e_pppk, s22g_pppk, s22s_pppk], [s22e_cppk, s22g_cppk, s22s_cppk]) }, name: ch(:previous_year), units: :kwh },
          { data: ->{ sum_data([s22e_cppk, s22g_cppk, s22s_cppk]) },                                name: ch(:last_year),  units: :kwh }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([s22e_pppk, s22g_pppk, s22s_pppk], [s22e_cppk, s22g_cppk, s22s_cppk]),
                                      sum_data([s22e_cppk, s22g_cppk, s22s_cppk]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # CO2
          { data: ->{ sum_if_complete([s22e_pppc, s22g_pppc, s22s_pppc], [s22e_cppc, s22g_cppc, s22s_cppc]) }, name: ch(:previous_year), units: :co2 },
          { data: ->{ sum_data([s22e_cppc, s22g_cppc, s22s_cppc]) },                                name: ch(:last_year),  units: :co2 }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([s22e_pppc, s22g_pppc, s22s_pppc], [s22e_cppc, s22g_cppc, s22s_cppc]),
                                      sum_data([s22e_cppc, s22g_cppc, s22s_cppc]),
                                      true
                                    ) },
            name: ch(:change_pct), units: :relative_percent_0dp
          },

          # £

          { data: ->{ sum_if_complete([s22e_ppp£, s22g_ppp£, s22s_ppp£], [s22e_cpp£, s22g_cpp£, s22s_cpp£]) }, name: ch(:previous_year), units: :£ },
          { data: ->{ sum_data([s22e_cpp£, s22g_cpp£, s22s_cpp£]) },                                name: ch(:last_year),  units: :£ }, 
          {
            data: ->{ percent_change(
                                      sum_if_complete([s22e_ppp£, s22g_ppp£, s22s_ppp£], [s22e_cpp£, s22g_cpp£, s22s_cpp£]),
                                      sum_data([s22e_cpp£, s22g_cpp£, s22s_cpp£]),
                                      true
                                    ) },
            name: ch(:change_£), units: :relative_percent_0dp, chart_data: true
          },

          # Metering

          { data: ->{
              [
                s22e_ppp£.nil? ? nil : 'Electricity',
                s22g_ppp£.nil? ? nil : 'Gas',
                s22s_ppp£.nil? ? nil : 'Storage Heaters'
              ].compact.join(', ')
            },
            name: ch(:metering),
            units: String
          },
          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 },
          { name: '',         span: 1 }
        ],
        where:   ->{ !sum_data([s22e_ppp£, s22g_ppp£, s22s_ppp£], true).nil? },
        sort_by:  [9],
        type: %i[chart table],
        admin_only: true
      },
      sept_nov_2021_2022_electricity_table: {
        benchmark_class:  BenchmarkSeptNov2022ElectricityTable,
        filter_out:     :dont_make_available_directly,
        name:       'September to November 2021 versus 2022 electricity use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ s22e_pppk }, name: ch(:previous_year), units: :kwh },
          { data: ->{ s22e_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(s22e_pppk, s22e_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ s22e_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ s22e_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(s22e_pppc, s22e_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ s22e_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ s22e_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(s22e_ppp£, s22e_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 3 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !s22e_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      sept_nov_2021_2022_gas_table: {
        benchmark_class:  BenchmarkSeptNov2022GasTable,
        filter_out:     :dont_make_available_directly,
        name:       'September to November 2021 versus 2022 gas use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ s22g_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ s22g_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ s22g_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(s22g_pppk, s22g_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ s22g_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ s22g_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(s22g_pppc, s22g_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ s22g_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ s22g_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(s22g_ppp£, s22g_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 4 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !s22g_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      sept_nov_2021_2022_storage_heater_table: {
        benchmark_class:  BenchmarkSeptNov2022StorageHeaterTable,
        filter_out:     :dont_make_available_directly,
        name:       'September to November 2021 versus 2022 storage heater use comparison',
        columns:  [
          tariff_changed_school_name,

          # kWh
          { data: ->{ s22s_pppu }, name: ch(:previous_year_temperature_unadjusted), units: :kwh },
          { data: ->{ s22s_pppk }, name: ch(:previous_year_temperature_adjusted), units: :kwh },
          { data: ->{ s22s_cppk }, name: ch(:last_year),  units: :kwh }, 
          { data: ->{ percent_change(s22s_pppk, s22s_cppk, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # CO2
          { data: ->{ s22s_pppc }, name: ch(:previous_year), units: :co2 },
          { data: ->{ s22s_cppc }, name: ch(:last_year),  units: :co2 }, 
          { data: ->{ percent_change(s22s_pppc, s22s_cppc, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          # £
          { data: ->{ s22s_ppp£ }, name: ch(:previous_year), units: :£ },
          { data: ->{ s22s_cpp£ }, name: ch(:last_year),  units: :£ }, 
          { data: ->{ percent_change(s22s_ppp£, s22s_cpp£, true) }, name: ch(:change_pct), units: :relative_percent_0dp },

          TARIFF_CHANGED_COL
        ],
        column_groups: [
          { name: '',         span: 1 },
          { name: 'kWh',      span: 4 },
          { name: 'CO2 (kg)', span: 3 },
          { name: 'Cost',     span: 3 }
        ],
        where:   ->{ !s22s_ppp£.nil? },
        sort_by:  [9],
        type: %i[table],
        admin_only: true
      },
      change_in_energy_since_last_year: {
        benchmark_class:  BenchmarkChangeInEnergySinceLastYear,
        name:     'Change in energy use since last year',
        columns:  [
          { data: 'addp_name',              name: ch(:name), units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },
          { data: ->{ sum_if_complete([enba_ken, enba_kgn, enba_khn, enba_ksn], 
                                      [enba_ke0, enba_kg0, enba_kh0, enba_ks0]) }, name: ch(:previous_year), units: :kwh },
          { data: ->{ sum_data([enba_ke0, enba_kg0, enba_kh0, enba_ks0]) }, name: ch(:last_year), units: :kwh },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_ken, enba_kgn, enba_khn, enba_ksn],
                          [enba_ke0, enba_kg0, enba_kh0, enba_ks0]
                        ),
                        sum_data([enba_ke0, enba_kg0, enba_kh0, enba_ks0]),
                        true
                      )
                    },
                    name: ch(:change_pct), units: :relative_percent_0dp
          },

          { data: ->{ sum_if_complete([enba_cen, enba_cgn, enba_chn, enba_csn], 
                                      [enba_ce0, enba_cg0, enba_ch0, enba_cs0]) }, name: ch(:previous_year), units: :co2 },
          { data: ->{ sum_data([enba_ce0, enba_cg0, enba_ch0, enba_cs0]) }, name: ch(:last_year), units: :co2 },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_cen, enba_cgn, enba_chn, enba_csn],
                          [enba_ce0, enba_cg0, enba_ch0, enba_cs0]
                        ),
                        sum_data([enba_ce0, enba_cg0, enba_ch0, enba_cs0]),
                        true
                      )
                    },
                    name: ch(:change_pct), units: :relative_percent_0dp
          },

          { data: ->{ sum_if_complete([enba_pen, enba_pgn, enba_phn, enba_psn], 
                                      [enba_pe0, enba_pg0, enba_ph0, enba_ps0]) }, name: ch(:previous_year), units: :£ },
          { data: ->{ sum_data([enba_pe0, enba_pg0, enba_ph0, enba_ps0]) }, name: ch(:last_year), units: :£ },
          { data: ->{ percent_change(
                        sum_if_complete(
                          [enba_pen, enba_pgn, enba_phn, enba_psn],
                          [enba_pe0, enba_pg0, enba_ph0, enba_ps0]
                        ),
                        sum_data([enba_pe0, enba_pg0, enba_ph0, enba_ps0]),
                        true
                      )
                    },
                    name: ch(:change_pct), units: :relative_percent_0dp
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
            name: ch(:fuel), units: String
          },
          { 
            data: ->{ 
              (enba_peap == ManagementSummaryTable::NO_RECENT_DATA_MESSAGE ||
               enba_pgap == ManagementSummaryTable::NO_RECENT_DATA_MESSAGE) ? 'Y' : ''
             },
             name: ch(:no_recent_data), units: String
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
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark },
        admin_only: false
      },
      change_in_electricity_since_last_year: {
        benchmark_class:  BenchmarkChangeInElectricitySinceLastYear,
        name:     'Change in electricity consumption since last year',
        columns:  [
          { data: 'addp_name',  name: ch(:name), units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_ken },                          name: ch(:previous_year),  units: :kwh },
          { data: ->{ enba_ke0 },                          name: ch(:last_year),      units: :kwh },
          { data: ->{ percent_change(enba_ken, enba_ke0)}, name: ch(:change_pct),         units: :relative_percent_0dp },

          { data: ->{ enba_cen },                          name: ch(:previous_year),  units: :co2 },
          { data: ->{ enba_ce0 },                          name: ch(:last_year),      units: :co2 },
          { data: ->{ percent_change(enba_cen, enba_ce0)}, name: ch(:change_pct),         units: :relative_percent_0dp },

          { data: ->{ enba_pen },                          name: ch(:previous_year),  units: :£ },
          { data: ->{ enba_pe0 },                          name: ch(:last_year),      units: :£ },
          { data: ->{ percent_change(enba_pen, enba_pe0)}, name: ch(:change_pct),         units: :relative_percent_0dp },

          { data: ->{ enba_solr == 'synthetic' ? 'Y' : '' }, name: ch(:estimated),  units: String },
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
        drilldown:  { type: :adult_dashboard, content_class: AdviceBenchmark },
        admin_only: false
      },
      change_in_gas_since_last_year: {
        benchmark_class:  BenchmarkChangeInGasSinceLastYear,
        name:     'Change in gas consumption since last year',
        columns:  [
          { data: 'addp_name',  name: ch(:name), units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_kgn  },                         name: ch(:previous_year),  units: :kwh },
          { data: ->{ gsba_kpya },                         name: ch(:previous_year_temperature_adjusted),  units: :kwh },
          { data: ->{ enba_kg0 },                          name: ch(:last_year),      units: :kwh },

          { data: ->{ enba_cgn },                          name: ch(:previous_year),  units: :co2 },
          { data: ->{ enba_cg0 },                          name: ch(:last_year),      units: :co2 },

          { data: ->{ enba_pgn },                          name: ch(:previous_year),  units: :£ },
          { data: ->{ enba_pg0 },                          name: ch(:last_year),      units: :£ },

          { data: ->{ percent_change(enba_kgn, enba_kg0)}, name: ch(:unadjusted_kwh),    units: :relative_percent_0dp },
          { data: ->{ gsba_adpc },                         name: ch(:temperature_adjusted_kwh), units: :relative_percent_0dp },
        ],
        column_groups: [
          { name: '',                 span: 1 },
          { name: 'kWh',              span: 3 },
          { name: 'CO2 (kg)',         span: 2 },
          { name: '£',                span: 2 },
          { name: 'Percent changed',  span: 2 },
        ],
        where:   ->{ !enba_kgn.nil? && enba_pgap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceGasLongTerm },
        admin_only: false        
      },
      change_in_storage_heaters_since_last_year: {
        benchmark_class:  BenchmarkChangeInStorageHeatersSinceLastYear,
        name:     'Change in storage heater consumption since last year',
        columns:  [
          { data: 'addp_name',  name: ch(:name), units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_khn  },                         name: ch(:previous_year),  units: :kwh },
          { data: ->{ shan_kpya },                         name: ch(:previous_year_temperature_adjusted),  units: :kwh },
          { data: ->{ enba_kh0 },                          name: ch(:last_year),      units: :kwh },

          { data: ->{ enba_chn },                          name: ch(:previous_year),  units: :co2 },
          { data: ->{ enba_ch0 },                          name: ch(:last_year),      units: :co2 },

          { data: ->{ enba_phn },                          name: ch(:previous_year),  units: :£ },
          { data: ->{ enba_ph0 },                          name: ch(:last_year),      units: :£ },

          { data: ->{ percent_change(enba_khn, enba_kh0)}, name: ch(:unadjusted_kwh),    units: :relative_percent_0dp },
          { data: ->{ shan_adpc },                         name: ch(:temperature_adjusted_kwh), units: :relative_percent_0dp },
        ],
        column_groups: [
          { name: '',                       span: 1 },
          { name: 'kWh',                    span: 3 },
          { name: 'CO2 (kg}',               span: 3 },
          { name: '£',                      span: 4 },
        ],
        where:   ->{ !enba_khn.nil? && enba_phap != ManagementSummaryTable::NO_RECENT_DATA_MESSAGE },
        sort_by:  [3],
        type: %i[table],
        drilldown:  { type: :adult_dashboard, content_class: AdviceStorageHeaters },
        admin_only: false        
      },
      change_in_solar_pv_since_last_year: {
        benchmark_class:  BenchmarkChangeInSolarPVSinceLastYear,
        name:     'Change in solar PV production since last year',
        columns:  [
          { data: 'addp_name',  name: ch(:name), units: :short_school_name, chart_data: true, content_class: AdviceBenchmark },

          { data: ->{ enba_ksn },                          name: ch(:previous_year),  units: :kwh },
          { data: ->{ enba_ks0 },                          name: ch(:last_year),      units: :kwh },
          { data: ->{ percent_change(enba_ksn, enba_ks0)}, name: ch(:change_pct),         units: :relative_percent_0dp },

          { data: ->{ enba_csn },                          name: ch(:previous_year),  units: :co2 },
          { data: ->{ enba_cs0 },                          name: ch(:last_year),      units: :co2 },
          { data: ->{ percent_change(enba_csn, enba_cs0)}, name: ch(:change_pct),         units: :relative_percent_0dp },

          { data: ->{ enba_solr == 'synthetic' ? 'Y' : '' }, name: ch(:estimated),  units: String },
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
        drilldown:  { type: :adult_dashboard, content_class: AdviceSolarPV },
        admin_only: false        
      },
      annual_electricity_costs_per_pupil: {
        benchmark_class:  BenchmarkContentElectricityPerPupil,
        name:     'Annual electricity use per pupil',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ elba_£pup },  name: ch(:last_year_electricity_£_pupil), units: :£_0dp, chart_data: true },
          { data: ->{ elba_£lyr },  name: ch(:last_year_electricity_£), units: :£},
          { data: ->{ elba_€esav }, name: ch(:saving_if_matched_exemplar_school), units: :£ },
          { data: ->{ elba_ratg },  name: ch(:rating), units: Float, y2_axis: true },
        ],
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[table],
        admin_only: false
      },
      change_in_annual_electricity_consumption: {
        benchmark_class:  BenchmarkContentChangeInAnnualElectricityConsumption,
        name:     'Change in annual electricity consumption',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ (elba_klyr - elba_kpyr) / elba_kpyr},  name: ch(:change_in_annual_electricity_usage), units: :relative_percent_0dp, chart_data: true },
          { data: ->{ elba_£lyr },  name: ch(:last_year_electricity_£), units: :£},
          { data: ->{ elba_£pyr },  name: ch(:previous_year_electricity_£), units: :£}
        ],
        where:   ->{ !elba_£pyr.nil? },
        sort_by:  [1], # column 1 i.e. Annual kWh
        type: %i[chart table],
        admin_only: true        
      },
      refrigeration: {
        benchmark_class:  BenchmarkRefrigeration,
        name:     'Last year cost of running refrigeration',
        columns:  [
          { data:   'addp_name',    name: ch(:name), units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ free_ann£ },  name: ch(:estimate_of_annual_refrigeration_cost), units: :£, chart_data: true },
          { data: ->{ free_hol£ },  name: ch(:saving_over_summer_holiday), units: :£, chart_data: true },
          { data: ->{ -1.0 * free_kwrd },  name: ch(:reduction_in_kw_over_summer_holiday), units: :kw},
        ],
        analytics_user_type: true,
        where:   ->{ !free_kwrd.nil? },
        sort_by:  [1], # column 1 i.e. annual refrigeration costs
        type: %i[chart table],
        admin_only: true
      },
      electricity_targets: {
        benchmark_class:  BenchmarkElectricityTarget,
        name:     'Progress versus electricity target',
        columns:  [
          { data:   'addp_name',    name: ch(:name), units: String, chart_data: true, content_class: AdviceElectricityAnnual },
          { data: ->{ etga_tptd },  name: ch(:percent_above_or_below_target_since_target_set), units: :relative_percent, chart_data: true },
          { data: ->{ etga_aptd },  name: ch(:percent_above_or_below_last_year),  units: :relative_percent},
          { data: ->{ etga_cktd },  name: ch(:kwh_consumption_since_target_set),  units: :kwh},
          { data: ->{ etga_tktd },  name: ch(:target_kwh_consumption),            units: :kwh},
          { data: ->{ etga_uktd },  name: ch(:last_year_kwh_consumption),         units: :kwh},
          { data: ->{ etga_trsd },  name: ch(:start_date_for_target),             units: :date},
        ],
        sort_by:  [1], # column 1 i.e. annual refrigeration costs
        type: %i[chart table],
        admin_only: false
      },
      annual_electricity_out_of_hours_use: {
        benchmark_class: BenchmarkContentElectricityOutOfHoursUsage,
        name:     'Electricity out of hours use',
        columns:  [
          tariff_changed_school_name(AdviceElectricityOutHours),
          { data: ->{ eloo_sdop },  name: ch(:school_day_open),              units: :percent, chart_data: true },
          { data: ->{ eloo_sdcp },  name: ch(:school_day_closed),            units: :percent, chart_data: true },
          { data: ->{ eloo_holp },  name: ch(:holiday),                      units: :percent, chart_data: true },
          { data: ->{ eloo_wkep },  name: ch(:weekend),                      units: :percent, chart_data: true },
          { data: ->{ eloo_comp },  name: ch(:community),                    units: :percent, chart_data: true },
          { data: ->{ eloo_com£ },  name: ch(:community_usage_cost),         units: :£ },
          { data: ->{ eloo_aoo£ },  name: ch(:last_year_out_of_hours_cost),  units: :£ },
          { data: ->{ eloo_esv€ },  name: ch(:saving_if_improve_to_exemplar),units: :£ },
          { data: ->{ eloo_ratg },  name: ch(:rating),                       units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      recent_change_in_baseload: {
        benchmark_class: BenchmarkContentChangeInBaseloadSinceLastYear,
        name:     'Last week\'s baseload versus average of last year (% difference)',
        columns:  [
          tariff_changed_school_name(AdviceBaseload),
          { data: ->{ elbc_bspc }, name: ch(:change_in_baseload_last_week_v_year_pct), units: :percent, chart_data: true},
          { data: ->{ elbc_blly }, name: ch(:average_baseload_last_year_kw), units: :kw},
          { data: ->{ elbc_bllw }, name: ch(:average_baseload_last_week_kw), units: :kw},
          { data: ->{ elbc_blch }, name: ch(:change_in_baseload_last_week_v_year_kw), units: :kw},
          { data: ->{ elbc_anc€ }, name: ch(:cost_of_change_in_baseload), units: :£current},
          { data: ->{ elbc_ratg }, name: ch(:rating), units: Float, y2_axis: true },
          blended_baseload_rate_col(->{ elbc_€prk }),
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !elbc_bspc.nil? },
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      baseload_per_pupil: {
        benchmark_class: BenchmarkContentBaseloadPerPupil,
        name:     'Baseload per pupil',
        columns:  [
          tariff_changed_school_name(AdviceBaseload),
          { data: ->{ elbb_blpp * 1000.0 }, name: ch(:baseload_per_pupil_w), units: :w, chart_data: true},
          { data: ->{ elbb_lygb },  name: ch(:last_year_cost_of_baseload), units: :£},
          { data: ->{ elbb_lykw },  name: ch(:average_baseload_kw), units: :w},
          { data: ->{ elbb_abkp },  name: ch(:baseload_percent), units: :percent},
          { data: ->{ [0.0, elbb_svex].max },  name: ch(:saving_if_moved_to_exemplar), units: :£},
          { data: ->{ elbb_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          blended_baseload_rate_col(->{ elbb_€prk }),
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !elbb_blpp.nil? },
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false        
      },
      seasonal_baseload_variation: {
        benchmark_class: BenchmarkSeasonalBaseloadVariation,
        name:     'Seasonal baseload variation',
        columns:  [
          tariff_changed_school_name(AdviceBaseload),
          { data: ->{ sblv_sblp }, name: ch(:percent_increase_on_winter_baseload_over_summer), units: :relative_percent, chart_data: true},
          { data: ->{ sblv_smbl },  name: ch(:summer_baseload_kw), units: :kw},
          { data: ->{ sblv_wtbl },  name: ch(:winter_baseload_kw), units: :kw},
          { data: ->{ sblv_c€bp },  name: ch(:saving_if_same_all_year_around), units: :£},
          { data: ->{ sblv_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          blended_baseload_rate_col(->{ sblv_€prk }),
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !sblv_sblp.nil? },
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      weekday_baseload_variation: {
        benchmark_class: BenchmarkWeekdayBaseloadVariation,
        name:     'Weekday baseload variation',
        columns:  [
          tariff_changed_school_name(AdviceBaseload),
          { data: ->{ iblv_sblp },  name: ch(:variation_in_baseload_between_days_of_week), units: :relative_percent, chart_data: true},
          { data: ->{ iblv_mnbk },  name: ch(:min_average_weekday_baseload_kw), units: :kw},
          { data: ->{ iblv_mxbk },  name: ch(:max_average_weekday_baseload_kw), units: :kw},
          { data: ->{ iblv_mnbd },  name: ch(:day_of_week_with_minimum_baseload), units: String},
          { data: ->{ iblv_mxbd },  name: ch(:day_of_week_with_maximum_baseload), units: String},
          { data: ->{ iblv_c€bp },  name: ch(:potential_saving), units: :£},
          { data: ->{ iblv_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          blended_baseload_rate_col(->{ iblv_€prk }),
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !iblv_sblp.nil? },
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      summer_holiday_electricity_analysis: {
        benchmark_class: BenchmarkContentSummerHolidayBaseloadAnalysis,
        name:     'Reduction in baseload in the summer holidays',
        columns:  [
          { data: 'addp_name',      name: ch(:name),      units: String },
          { data: ->{ shol_ann£ },  name: ch(:annualised_£_value_of_summer_holiday_reduction),    units: :£, chart_data: true },
          { data: ->{ shol_hol£ },  name: ch(:saving_during_summer_holiday_from_baseload_reduction),  units: :£ },
          { data: ->{ shol_kwrd },  name: ch(:reduction_in_baseload_over_summer_holidays), units: :kw },
          { data: ->{ shol_rrat },  name: ch(:size_of_reduction_rating),  units: Float },
          { data: ->{ shol_trat },  name: ch(:rating_based_on_number_of_recent_years_with_reduction),  units: Float },
          { data: ->{ shol_ratg },  name: ch(:overall_rating),  units: Float },
        ],
        analytics_user_type: true,
        sort_by: [1],
        type: %i[table],
        admin_only: true        
      },
      electricity_peak_kw_per_pupil: {
        benchmark_class: BenchmarkContentPeakElectricityPerFloorArea,
        name:     'Peak school day electricity comparison kW/floor area',
        columns:  [
          tariff_changed_school_name(AdviceElectricityIntraday),
          { data: ->{ epkb_kwfa * 1000.0 },  name: ch(:w_floor_area),    units: :w, chart_data: true },
          { data: ->{ epkb_kwsc },  name: ch(:average_peak_kw),  units: :kw },
          { data: ->{ epkb_kwex },  name: ch(:exemplar_peak_kw), units: :kw },
          { data: ->{ epkb_tex£ },  name: ch(:saving_if_match_exemplar_£), units: :£ },
          { data: ->{ epkb_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !epkb_kwfa.nil? },
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      solar_pv_benefit_estimate: {
        benchmark_class: BenchmarkContentSolarPVBenefit,
        name:     'Benefit of estimated optimum size solar PV installation',
        columns:  [
          tariff_changed_school_name(AdviceSolarPV),
          { data: ->{ sole_opvk },  name: ch(:size_kwp),    units: :kwp},
          { data: ->{ sole_opvy },  name: ch(:payback_years),  units: :years },
          { data: ->{ sole_opvp },  name: ch(:reduction_in_mains_consumption_pct), units: :percent },
          { data: ->{ sole_opv€ },  name: ch(:saving_optimal_panels), units: :£current },
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !sole_opvk.nil? },
        sort_by: [1],
        type: %i[table],
        admin_only: false        
      },
      annual_heating_costs_per_floor_area: {
        benchmark_class:  BenchmarkContentHeatingPerFloorArea,
        name:     'Annual heating cost per floor area',
        columns:  [
          tariff_changed_school_name(AdviceGasAnnual),
          { data: ->{ sum_data([gsba_n£m2, shan_n£m2], true) },  name: ch(:last_year_heating_costs_per_floor_area), units: :£, chart_data: true },
          { data: ->{ sum_data([gsba_£lyr, shan_£lyr], true) },  name: ch(:last_year_cost_£), units: :£},
          { data: ->{ sum_data([gsba_s€ex, shan_s€ex], true) },  name: ch(:saving_if_matched_exemplar_school), units: :£ },
          { data: ->{ sum_data([gsba_klyr, shan_klyr], true) },  name: ch(:last_year_consumption_kwh), units: :kwh},
          { data: ->{ sum_data([gsba_co2y, shan_co2y], true) / 1000.0 },  name: ch(:last_year_carbon_emissions_tonnes_co2), units: :co2},
          { data: ->{ or_nil([gsba_ratg, shan_ratg]) },  name: ch(:rating), units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !gsba_co2y.nil? },
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false        
      },
      change_in_annual_heating_consumption: {
        benchmark_class:  BenchmarkContentChangeInAnnualHeatingConsumption,
        name:     'Change in annual heating consumption',
        columns:  [
          tariff_changed_school_name(AdviceGasAnnual),

          { data: ->{ percent_change([gsba_£pyr, shan_£pyr], [gsba_£lyr, shan_£lyr], true) },  name: ch(:change_in_annual_gas_storage_heater_usage), units: :relative_percent_0dp, sense: :positive_is_bad, chart_data: true },

          { data: ->{ gsba_£pyr },  name: ch(:previous_year_gas_costs_£), units: :£},
          { data: ->{ gsba_£lyr },  name: ch(:last_year_gas_costs_£), units: :£},

          { data: ->{ shan_£pyr },  name: ch(:previous_year_storage_heater_costs_£), units: :£},
          { data: ->{ shan_£lyr },  name: ch(:last_year_storage_heater_costs_£), units: :£},

          { data: ->{ sum_data([gsba_£lyr, shan_£lyr]) - sum_data([gsba_£pyr, shan_£pyr]) },  name: ch(:change_in_heating_costs_between_last_2_years), units: :£},
          TARIFF_CHANGED_COL
        ],
        where:   ->{ !gsba_£pyr.nil? || !shan_£pyr.nil? },
        sort_by:  [1], # column 1 i.e. Annual kWh
        treat_as_nil:   [0],
        type: %i[chart table],
        admin_only: true        
      },
      change_in_annual_heating_consumption_temperature_adjusted: {
        benchmark_class:  BenchmarkContentChangeInAnnualHeatingConsumptionTemperatureAdjusted,
        filter_out:     :dont_make_available_directly,
        name:     'Change in annual heating consumption (temperature adjusted)',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true, content_class: AdviceGasAnnual },
          { data: ->{ percent_change([gsba_kpyr, shan_kpyr], [gsba_klyr, shan_klyr], true) },  name: ch(:temperature_unadjusted), units: :relative_percent_0dp, sense: :positive_is_bad},
          { data: ->{ percent_change([gsba_kpya, shan_kpya], [gsba_klyr, shan_klyr], true) },  name: ch(:temperature_adjusted), units: :relative_percent_0dp, sense: :positive_is_bad, chart_data: true },
          
          { data: ->{ gsba_kpyr },  name: ch(:previous_year_temperature_unadjusted), units: :kwh},
          { data: ->{ gsba_kpya },  name: ch(:previous_year_temperature_adjusted),   units: :kwh},
          { data: ->{ gsba_klyr },  name: ch(:last_year),                            units: :kwh},

          { data: ->{ shan_kpyr },  name: ch(:previous_year_temperature_unadjusted), units: :kwh},
          { data: ->{ shan_kpya },  name: ch(:previous_year_temperature_adjusted),   units: :kwh},         
          { data: ->{ shan_klyr },  name: ch(:last_year),                            units: :kwh},

          { data: ->{ sum_data([gsba_klyr, shan_klyr]) - sum_data([gsba_kpyr, shan_kpyr]) },  name: ch(:temperature_unadjusted), units: :kwh},
          { data: ->{ sum_data([gsba_klyr, shan_klyr]) - sum_data([gsba_kpya, shan_kpya]) },  name: ch(:temperature_adjusted),   units: :kwh}
        ],
        column_groups: [
          { name: '',                             span: 1 },
          { name: 'Percent change (Heating)',     span: 2 },
          { name: 'Gas (kWh)',                    span: 3 },
          { name: 'Storage heaters (kWh)',        span: 3 },
          { name: 'Change in consumption (kWh)',  span: 2 },
        ],
        where:   ->{ !gsba_kpyr.nil? || !shan_kpyr.nil? },
        sort_by:  [1], # column 1 i.e. Annual kWh
        treat_as_nil:   [0],
        type: %i[chart table],
        admin_only: true        
      },
      annual_gas_out_of_hours_use: {
        benchmark_class: BenchmarkContentGasOutOfHoursUsage,
        name:     'Gas: out of hours use',
        columns:  [
          tariff_changed_school_name(AdviceGasOutHours),
          { data: ->{ gsoo_sdop },  name: ch(:school_day_open),              units: :percent, chart_data: true },
          { data: ->{ gsoo_sdcp },  name: ch(:school_day_closed),            units: :percent, chart_data: true },
          { data: ->{ gsoo_holp },  name: ch(:holiday),                      units: :percent, chart_data: true },
          { data: ->{ gsoo_wkep },  name: ch(:weekend),                      units: :percent, chart_data: true },
          { data: ->{ gsoo_comp },  name: ch(:community),                    units: :percent, chart_data: true },
          { data: ->{ gsoo_com£ },  name: ch(:community_usage_cost),         units: :£ },
          { data: ->{ gsoo_aoo£ },  name: ch(:last_year_out_of_hours_cost),     units: :£ },
          { data: ->{ gsoo_esv€ },  name: ch(:saving_if_improve_to_exemplar),units: :£ },
          { data: ->{ gsoo_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      gas_targets: {
        benchmark_class:  BenchmarkGasTarget,
        name:     'Progress versus gas target',
        columns:  [
          { data:   'addp_name',    name: ch(:name), units: String, chart_data: true, content_class: AdviceGasAnnual },
          { data: ->{ gtga_tptd },  name: ch(:percent_above_or_below_target_since_target_set), units: :relative_percent, chart_data: true },
          { data: ->{ gtga_aptd },  name: ch(:percent_above_or_below_last_year),  units: :relative_percent},
          { data: ->{ gtga_cktd },  name: ch(:kwh_consumption_since_target_set),  units: :kwh},
          { data: ->{ gtga_tktd },  name: ch(:target_kwh_consumption),            units: :kwh},
          { data: ->{ gtga_uktd },  name: ch(:last_year_kwh_consumption),         units: :kwh},
          { data: ->{ gtga_trsd },  name: ch(:start_date_for_target),             units: :date},
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      annual_storage_heater_out_of_hours_use: {
        benchmark_class: BenchmarkContentStorageHeaterOutOfHoursUsage,
        name:     'Storage heater out of hours use',
        columns:  [
          { data: 'addp_name',      name: ch(:name),                  units: String,   chart_data: true, content_class: AdviceStorageHeaters },
          { data: ->{ shoo_sdop },  name: ch(:school_day_open),              units: :percent, chart_data: true },
          { data: ->{ shoo_sdcp },  name: ch(:overnight_charging),           units: :percent, chart_data: true },
          { data: ->{ shoo_holp },  name: ch(:holiday),                      units: :percent, chart_data: true },
          { data: ->{ shoo_wkep },  name: ch(:weekend),                      units: :percent, chart_data: true },
          { data: ->{ sum_data([shoo_ahl£, shoo_awk£], true)  },  name: ch(:last_year_weekend_and_holiday_costs), units: :£ },
          { data: ->{ shoo_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      heating_coming_on_too_early: {
        benchmark_class:  BenchmarkHeatingComingOnTooEarly,
        name:     'Heating start time (potentially coming on too early in morning)',
        columns:  [
          { data: 'addp_name',      name: ch(:name),                                    units: String,   chart_data: true, content_class: AdviceGasBoilerMorningStart },
          { data: ->{ hthe_htst },  name: ch(:average_heating_start_time_last_week),    units: :timeofday, chart_data: true },
          { data: ->{ opts_avhm },  name: ch(:average_heating_start_time_last_year),    units: :timeofday },
          { data: ->{ hthe_oss€ },  name: ch(:last_year_saving_if_improve_to_exemplar), units: :£ },
          { data: ->{ hthe_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          TARIFF_CHANGED_COL
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      optimum_start_analysis: {
        benchmark_class:  BenchmarkOptimumStartAnalysis,
        filter_out:     :dont_make_available_directly,
        name:     'Optimum start analysis',
        columns:  [
          { data: 'addp_name',      name: ch(:name),      units: String, chart_data: true },
          { data: ->{ opts_avhm },  name: ch(:average_heating_start_time_last_year),    units: :timeofday, chart_data: true },
          { data: ->{ opts_sdst },  name: ch(:standard_deviation_of_start_time__hours_last_year),  units: :opt_start_standard_deviation },
          { data: ->{ opts_ratg },  name: ch(:optimum_start_rating), units: Float },
          { data: ->{ opts_rmst },  name: ch(:regression_model_optimum_start_time),  units: :morning_start_time },
          { data: ->{ opts_rmss },  name: ch(:regression_model_optimum_start_sensitivity_to_outside_temperature),  units: :optimum_start_sensitivity },
          { data: ->{ opts_rmr2 },  name: ch(:regression_model_optimum_start_r2),  units: :r2 },
          { data: ->{ hthe_htst },  name: ch(:average_heating_start_time_last_week), units: :timeofday},
        ],
        sort_by: [1],
        type: %i[chart table],
        admin_only: true
      },
      thermostat_sensitivity: {
        benchmark_class:  BenchmarkContentThermostaticSensitivity,
        name:     'Annual saving through 1C reduction in thermostat temperature',
        columns:  [
          { data: 'addp_name',      name: ch(:name),                  units: String,   chart_data: true },
          { data: ->{ htsa_td1c },  name: ch(:last_year_saving_per_1c_reduction_in_thermostat), units: :£, chart_data: true },
          { data: ->{ htsa_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      heating_in_warm_weather: {
        benchmark_class:  BenchmarkContentHeatingInWarmWeather,
        name:     'Gas or storage heater consumption for heating in warm weather',
        columns:  [
          { data: 'addp_name',      name: ch(:name),           units: String, chart_data: true, content_class: AdviceGasBoilerSeasonalControl },
          { data: ->{ or_nil([shsd_wpan, shsh_wpan]) },  name: ch(:percentage_of_annual_heating_consumed_in_warm_weather), units: :percent, chart_data: true },
          { data: ->{ or_nil([shsd_wkwh, shsh_wkwh]) },  name: ch(:saving_through_turning_heating_off_in_warm_weather_kwh), units: :kwh },
          { data: ->{ or_nil([shsd_wco2, shsh_wco2]) },  name: ch(:saving_co2_kg), units: :co2 },
          { data: ->{ or_nil([shsd_w€__, shsh_w€__]) },  name: ch(:saving_£), units: :£ },
          { data: ->{ or_nil([shsd_wdys, shsh_wdys]) },  name: ch(:number_of_days_heating_on_in_warm_weather), units: :days },
          { data: ->{ or_nil([shsd_ratg, shsh_ratg]) },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[chart table],
        admin_only: false
      },
      thermostatic_control: {
        benchmark_class:  BenchmarkContentThermostaticControl,
        name:     'Quality of thermostatic control',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true, content_class: AdviceGasThermostaticControl },
          { data: ->{ or_nil([httc_r2, shtc_r2]) },    name: ch(:thermostatic_r2), units: :r2,  chart_data: true },
          { data: ->{ sum_data([httc_sav€, shtc_sav€], true) },  name: ch(:saving_through_improved_thermostatic_control), units: :£ },
          { data: ->{ httc_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by: [1],
        type: %i[chart table],
        admin_only: false
      },
      hot_water_efficiency: {
        benchmark_class:  BenchmarkContentHotWaterEfficiency,
        name:     'Hot Water Efficiency',
        columns:  [
          { data: 'addp_name',      name: ch(:name), units: String, chart_data: true, content_class: AdviceGasHotWater },
          { data: ->{ hotw_ppyr },  name: ch(:cost_per_pupil), units: :£, chart_data: true},
          { data: ->{ hotw_eff  },  name: ch(:efficiency_of_system), units: :percent},
          { data: ->{ hotw_gsav },  name: ch(:saving_improving_timing), units: :£},
          { data: ->{ hotw_esav },  name: ch(:saving_with_pou_electric_hot_water), units: :£},
          { data: ->{ hotw_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        type: %i[chart table],
        admin_only: false
      },
      electricity_meter_consolidation_opportunities: {
        benchmark_class:  BenchmarkContentElectricityMeterConsolidation,
        name:     'Opportunities for electricity meter consolidation',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ emtc_sav£ },  name: ch(:potential_max_annual_saving_£), units: :£,  chart_data: true },
          { data: ->{ emtc_mets },  name: ch(:number_of_electricity_meters), units: :meters },
          { data: ->{ emtc_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
        type: %i[table chart],
        admin_only: true
      },
      gas_meter_consolidation_opportunities: {
        benchmark_class:  BenchmarkContentGasMeterConsolidation,
        name:     'Opportunities for gas meter consolidation',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ gmtc_sav£ },  name: ch(:potential_max_annual_saving_£), units: :£,  chart_data: true },
          { data: ->{ gmtc_mets },  name: ch(:number_of_gas_meters), units: :meters },
          { data: ->{ gmtc_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
        type: %i[table chart],
        admin_only: true
      },
      differential_tariff_opportunity: {
        benchmark_class:  BenchmarkContentDifferentialTariffOpportunity,
        name:     'Benefit of moving to or away from a differential tariff',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ dtaf_sav£ },  name: ch(:potential_annual_saving_£), units: :£,  chart_data: true },
          { data: ->{ dtaf_ratg },  name: ch(:rating), units: Float, y2_axis: true }
        ],
        sort_by:  [1],
        # sort_by: [{ reverse: 1}],
        type: %i[table chart],
        admin_only: true
      },
      change_in_electricity_consumption_recent_school_weeks: {
        benchmark_class:  BenchmarkContentChangeInElectricityConsumptionSinceLastSchoolWeek,
        name:     'Change in electricity consumption since last school week',
        columns:  [
          { data: ->{ referenced(addp_name, eswc_pnch, eswc_difp, eswc_cppp) }, name: ch(:name), units: String, chart_data: true, column_id: :school_name },
          { data: ->{ eswc_difp },  name: ch(:change_pct), units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ eswc_dif€ },  name: ch(:change_£current),   units: :£_0dp },
          { data: ->{ eswc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ eswc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ eswc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ eswc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
          tariff_changed_between_periods(->{ eswc_cppp })
        ],
        where:   ->{ !eswc_difk.nil? },
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      change_in_electricity_holiday_consumption_previous_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetweenLast2Holidays,
        name:     'Change in electricity consumption between the 2 most recent holidays',
        columns:  [
          { data: ->{ referenced(addp_name, ephc_pnch, ephc_difp, ephc_cppp) }, name: ch(:name),     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ ephc_difp },  name: ch(:change_pct), units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ ephc_dif€ },  name: ch(:change_£current), units: :£_0dp },
          { data: ->{ ephc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ partial(ephc_cper, ephc_cptr) },  name: ch(:most_recent_holiday), units: String },
          { data: ->{ ephc_pper },  name: ch(:previous_holiday), units: String },
          { data: ->{ ephc_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          { data: ->{ ephc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ ephc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ ephc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
          tariff_changed_between_periods(->{ ephc_cppp })
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      change_in_electricity_holiday_consumption_previous_years_holiday: {
        benchmark_class: BenchmarkContentChangeInElectricityBetween2HolidaysYearApart,
        name:     'Change in electricity consumption between this holiday and the same holiday the previous year',
        columns:  [
          { data: ->{ referenced(addp_name, epyc_pnch, epyc_difp, epyc_cppp) }, name: ch(:name),     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ epyc_difp },  name: ch(:change_pct), units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ epyc_dif€ },  name: ch(:change_£current), units: :£_0dp },
          { data: ->{ epyc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ partial(epyc_cper, epyc_cptr) },  name: ch(:most_recent_holiday), units: String },
          { data: ->{ epyc_pper },  name: ch(:previous_holiday), units: String },
          { data: ->{ epyc_pnch },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :pupils_changed},
          { data: ->{ epyc_cpnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :current_pupils},
          { data: ->{ epyc_ppnp },  aggregate_column: :dont_display_in_table_or_chart, units: :pupils, column_id: :previous_pupils},
          { data: ->{ epyc_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          tariff_changed_between_periods(->{ epyc_cppp })
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      electricity_consumption_during_holiday: {
        benchmark_class: BenchmarkElectricityOnDuringHoliday,
        name:     'Electricity consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ edhl_£pro },  name: ch(:projected_usage_by_end_of_holiday), units: :£, chart_data: true },
          { data: ->{ edhl_£sfr },  name: ch(:holiday_usage_to_date), units: :£ },
          { data: ->{ edhl_hnam },  name: ch(:holiday), units: String }
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      change_in_gas_consumption_recent_school_weeks: {
        benchmark_class: BenchmarkContentChangeInGasConsumptionSinceLastSchoolWeek,
        name:     'Change in gas consumption since last school week',
        columns:  [
          { data: ->{ referenced(addp_name, gswc_pnch, gswc_difp, gswc_cppp) }, name: ch(:name),     units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gswc_difp },  name: ch(:change_pct), units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ gswc_dif€ },  name: ch(:change_£current), units: :£_0dp },
          { data: ->{ gswc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ gswc_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          { data: ->{ gswc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :floor_area_changed},
          { data: ->{ gswc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :current_floor_area},
          { data: ->{ gswc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :previous_floor_area},
          tariff_changed_between_periods(->{ gswc_cppp })
        ],
        max_x_value:   100,
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      change_in_gas_holiday_consumption_previous_holiday: {
        benchmark_class: BenchmarkContentChangeInGasBetweenLast2Holidays,
        name:     'Change in gas consumption between the 2 most recent holidays',
        columns:  [
          { data: ->{ referenced(addp_name, gphc_pnch, gphc_difp, gphc_cppp) }, name: ch(:name), units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gphc_difp },  name: ch(:change_pct), units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ gphc_dif€ },  name: ch(:change_£current), units: :£_0dp },
          { data: ->{ gphc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ partial(gphc_cper, gphc_cptr) },  name: ch(:most_recent_holiday), units: String },
          { data: ->{ gphc_pper },  name: ch(:previous_holiday), units: String },
          { data: ->{ gphc_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          { data: ->{ gphc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass, column_id: :floor_area_changed},
          { data: ->{ gphc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :current_floor_area},
          { data: ->{ gphc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2, column_id: :previous_floor_area},
          tariff_changed_between_periods(->{ gphc_cppp })
        ],
        sort_by: [1],
        max_x_value:   100,
        # min_x_value:  -5,
        type: %i[table chart],
        admin_only: false
      },
      change_in_gas_holiday_consumption_previous_years_holiday: {
        benchmark_class: BenchmarkContentChangeInGasBetween2HolidaysYearApart,
        name:     'Change in gas consumption between this holiday and the same the previous year',
        columns:  [
          { data: ->{ referenced(addp_name, gpyc_pnch, gpyc_difp, gpyc_cppp) }, name: ch(:name), units: String, chart_data: true, column_id: :school_name },
          { data: ->{ gpyc_difp },  name: ch(:change_pct),   units: :relative_percent_0dp, chart_data: true, column_id: :percent_changed },
          { data: ->{ gpyc_dif€ },  name: ch(:change_£current),   units: :£_0dp },
          { data: ->{ gpyc_difk },  name: ch(:change_kwh), units: :kwh },
          { data: ->{ partial(gpyc_cper, gpyc_cptr) },  name: ch(:most_recent_holiday), units: String },
          { data: ->{ gpyc_pper },  name: ch(:previous_holiday), units: String },
          { data: ->{ gpyc_ratg },  name: ch(:rating), units: Float, y2_axis: true },
          { data: ->{ gpyc_fach },  aggregate_column: :dont_display_in_table_or_chart, units: TrueClass,  column_id: :floor_area_changed},
          { data: ->{ gpyc_cpfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2,        column_id: :current_floor_area},
          { data: ->{ gpyc_ppfa },  aggregate_column: :dont_display_in_table_or_chart, units: :m2,        column_id: :previous_floor_area},
          tariff_changed_between_periods(->{ gpyc_cppp })
        ],
        max_x_value:   100,
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      gas_consumption_during_holiday: {
        benchmark_class: BenchmarkGasHeatingHotWaterOnDuringHoliday,
        name:     'Gas consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ hdhl_£pro },  name: ch(:projected_usage_by_end_of_holiday), units: :£, chart_data: true },
          { data: ->{ hdhl_£sfr },  name: ch(:holiday_usage_to_date), units: :£ },
          { data: ->{ hdhl_hnam },  name: ch(:holiday), units: String }
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      storage_heater_consumption_during_holiday: {
        benchmark_class: BenchmarkStorageHeatersOnDuringHoliday,
        name:     'Storage heater consumption during current holiday',
        columns:  [
          { data: 'addp_name',      name: ch(:name),     units: String, chart_data: true },
          { data: ->{ shoh_£pro },  name: ch(:projected_usage_by_end_of_holiday), units: :£, chart_data: true },
          { data: ->{ shoh_£sfr },  name: ch(:holiday_usage_to_date), units: :£ },
          { data: ->{ shoh_hnam },  name: ch(:holiday), units: String }
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      holiday_usage_last_year:  {
        benchmark_class: BenchmarkEnergyConsumptionInUpcomingHolidayLastYear,
        name:     'Energy Consumption in upcoming holiday last year',
        columns:  [
          { data: 'addp_name',      name: ch(:name),                       units: String, chart_data: true },
          { data: ->{ ihol_glyr },  name: ch(:gas_cost_ht),                units: :£, chart_data: true  },
          { data: ->{ ihol_elyr },  name: ch(:electricity_cost_ht),        units: :£, chart_data: true },
          { data: ->{ ihol_g£ly },  name: ch(:gas_cost_ct),                units: :£, chart_data: true  },
          { data: ->{ ihol_e£ly },  name: ch(:electricity_cost_ct),        units: :£, chart_data: true },
          { data: ->{ ihol_gpfa },  name: ch(:gas_kwh_per_floor_area),     units: :kwh },
          { data: ->{ ihol_epup },  name: ch(:electricity_kwh_per_pupil),  units: :kwh },
          { data: ->{ ihol_pper },  name: ch(:holiday),                    units: String },
        ],
        sort_by: [1],
        type: %i[table chart],
        admin_only: false
      },
      school_information: {
        benchmark_class:  nil,
        filter_out:     :dont_make_available_directly,
        name:     'School information - used for drilldown, not directly presented to user',
        columns:  [
          # the ordered and index of these 3 columns is important as hardcoded
          # indexes are used else where in the code [0] etc. to map between id and urn
          # def school_map()
          { data: 'addp_name',     name: ch(:name), units: String,  chart_data: false },
          { data: 'addp_urn',      name: ch(:urn),         units: Integer, chart_data: false },
          { data: ->{ school_id }, name: ch(:school_id),   units: Integer, chart_data: false  }
        ],
        sort_by: [1],
        type: %i[table],
        admin_only: true
      },
    }.freeze
  end
end
