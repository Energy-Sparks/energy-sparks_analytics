require_relative './benchmark_no_text_mixin.rb'
require_relative './benchmark_content_base.rb'

module Benchmarking
  class BenchmarkContentEnergyPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text =  I18n.t('analytics.benchmarking.content.annual_energy_costs_per_pupil.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_per_pupil_v_per_floor_area_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_doesnt_have_all_meter_data_html')
      ERB.new(text).result(binding)
    end
  end
#=======================================================================================
  class BenchmarkOptimumStartAnalysis  < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      I18n.t('analytics.benchmarking.content.optimum_start_analysis.introduction_text_html')
    end

    protected def table_introduction_text
      I18n.t('analytics.benchmarking.content.optimum_start_analysis.table_introduction_text_html')
    end

    protected def caveat_text
      I18n.t('analytics.benchmarking.content.optimum_start_analysis.caveat_text_html')
    end
  end


  #=======================================================================================
  class BenchmarkContentChangeInEnergyUseSinceJoinedFullData < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text =  I18n.t('analytics.benchmarking.content.change_in_energy_use_since_joined_full_data.introduction_text_html')
      ERB.new(text).result(binding)
    end
  end  
  #=======================================================================================
  class BenchmarkContentTotalAnnualEnergy < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.annual_energy_costs.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_doesnt_have_all_meter_data_html')
      ERB.new(text).result(binding)
    end
    protected def table_interpretation_text
      I18n.t('analytics.benchmarking.caveat_text.es_data_not_in_sync_html')
    end
  end
  #=======================================================================================
  class BenchmarkContentElectricityPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.annual_electricity_costs_per_pupil.introduction_text_html')
    end
  end
  #=======================================================================================
  class BenchmarkContentElectricityOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.annual_electricity_out_of_hours_use.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv_html')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkBaseloadBase < BenchmarkContentBase   
    def content(school_ids: nil, filter: nil, user_type: nil)
      @baseload_impact_html = baseload_1_kw_change_range_£_html(school_ids, filter, user_type)
      super(school_ids: school_ids, filter: filter)
    end

    private

    def baseload_1_kw_change_range_£_html(school_ids, filter, user_type)
      cost_of_1_kw_baseload_range_£ = calculate_cost_of_1_kw_baseload_range_£(school_ids, filter, user_type)

      cost_of_1_kw_baseload_range_£_html = cost_of_1_kw_baseload_range_£.map do |costs_£|
        FormatEnergyUnit.format(:£, costs_£, :html)
      end

      text = %q(
        <p>
          <% if cost_of_1_kw_baseload_range_£_html.empty? %>

          <% elsif cost_of_1_kw_baseload_range_£_html.length == 1 %>
            A 1 kW increase in baseload is equivalent to an increase in
            annual electricity costs of <%= cost_of_1_kw_baseload_range_£_html.first %>.
          <% else %>
            A 1 kW increase in baseload is equivalent to an increase in
            annual electricity costs of between <%= cost_of_1_kw_baseload_range_£_html.first %>
            and <%= cost_of_1_kw_baseload_range_£_html.last %> depending on your current tariff.
          <% end %>    
        </p>
      )
      ERB.new(text).result(binding)
    end

    def calculate_cost_of_1_kw_baseload_range_£(school_ids, filter, user_type)
      rates = calculate_blended_rate_range(school_ids, filter, user_type)

      hours_per_year = 24.0 * 365
      rates.map { |rate| rate * hours_per_year }
    end

    def calculate_blended_rate_range(school_ids, filter, user_type)
      blended_current_rate_header = I18n.t("analytics.benchmarking.configuration.column_headings.blended_current_rate")
      col_index = column_headings(school_ids, filter, user_type).index(blended_current_rate_header)
      data = raw_data(school_ids, filter, user_type)
      return [] if data.nil? || data.empty?

      blended_rate_per_kwhs = data.map { |row| row[col_index] }.compact

      blended_rate_per_kwhs.map { |rate| rate.round(2) }.minmax.uniq
    end
  end

  #=======================================================================================
  class BenchmarkContentChangeInBaseloadSinceLastYear < BenchmarkBaseloadBase
    include BenchmarkingNoTextMixin

    def introduction_text
      text = I18n.t('analytics.benchmarking.content.recent_change_in_baseload.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')

      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkElectricityTarget < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.electricity_targets.introduction_text_html')
      ERB.new(text).result(binding)
    end
  end
    #=======================================================================================
    class BenchmarkGasTarget < BenchmarkContentBase
      include BenchmarkingNoTextMixin
  
      private def introduction_text
        text = I18n.t('analytics.benchmarking.content.gas_targets.introduction_text_html')
        ERB.new(text).result(binding)
      end
    end
  #=======================================================================================
  class BenchmarkContentBaseloadPerPupil < BenchmarkBaseloadBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.baseload_per_pupil.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv')

      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================
  class BenchmarkSeasonalBaseloadVariation < BenchmarkBaseloadBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.seasonal_baseload_variation.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv')
      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================
  class BenchmarkWeekdayBaseloadVariation < BenchmarkBaseloadBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.weekday_baseload_variation.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv')
      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================
  class BenchmarkContentPeakElectricityPerFloorArea < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.electricity_peak_kw_per_pupil.introduction_text_html')
      ERB.new(text).result(binding)      
    end
  end
    #=======================================================================================
    class BenchmarkContentSolarPVBenefit < BenchmarkContentBase
      include BenchmarkingNoTextMixin
      private def introduction_text
        text = I18n.t('analytics.benchmarking.content.solar_pv_benefit_estimate.introduction_text_html')
        ERB.new(text).result(binding)      
      end
    end
    #=======================================================================================
    class BenchmarkContentHeatingPerFloorArea < BenchmarkContentBase
      include BenchmarkingNoTextMixin
      private def introduction_text
        I18n.t('analytics.benchmarking.content.annual_heating_costs_per_floor_area.introduction_text_html')
      end
    end

  #=======================================================================================
  class BenchmarkContentGasOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      I18n.t('analytics.benchmarking.content.annual_gas_out_of_hours_use.introduction_text_html')
    end
  end
  #=======================================================================================
  class BenchmarkContentStorageHeaterOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.annual_storage_heater_out_of_hours_use.introduction_text_html')
    end
  end
  #=======================================================================================
  class BenchmarkContentThermostaticSensitivity < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.thermostat_sensitivity.introduction_text_html')
    end
  end
    #=======================================================================================
    class BenchmarkContentHeatingInWarmWeather < BenchmarkContentBase
      include BenchmarkingNoTextMixin
      private def introduction_text
        I18n.t('analytics.benchmarking.content.heating_in_warm_weather.introduction_text_html')
      end
    end
  #=======================================================================================
  class BenchmarkContentThermostaticControl < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.thermostatic_control.introduction_text_html')
    end
  end
  #=======================================================================================
  class BenchmarkContentHotWaterEfficiency < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.hot_water_efficiency.introduction_text_html')
    end
  end
  #=======================================================================================
  # 2 sets of charts, tables on one page
  class BenchmarkHeatingComingOnTooEarly < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      I18n.t('analytics.benchmarking.content.heating_coming_on_too_early.introduction_text_html')
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = optimum_start_content(school_ids: school_ids, filter: filter)
      content1 + content2
    end

    private

    def optimum_start_content(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :optimum_start_analysis, filter: filter)
    end
  end

  #=======================================================================================
  class BenchmarkContentEnergyPerFloorArea < BenchmarkContentBase
    # config key annual_energy_costs_per_floor_area
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = '<p>'
      text += I18n.t('analytics.benchmarking.content.annual_energy_costs_per_floor_area.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_per_pupil_v_per_floor_area_useful_html')
      text += '</p>'
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInEnergyUseSinceJoined < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_energy_use_since_joined_energy_sparks.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')

      ERB.new(text).result(binding)
    end
    protected def chart_interpretation_text
      text = I18n.t('analytics.benchmarking.content.change_in_energy_use_since_joined_energy_sparks.chart_interpretation_text_html')
      ERB.new(text).result(binding)
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = full_energy_change_breakdown(school_ids: school_ids, filter: filter)
      content1 + content2
    end

    private

    def full_energy_change_breakdown(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :change_in_energy_use_since_joined_energy_sparks_full_data, filter: filter)
    end
  end
  #=======================================================================================
  # shared wording save some translation costs
  class BenchmarkAnnualChangeBase < BenchmarkContentBase
    def table_introduction(fuel_types, direction = 'use')
      text = %q(
        <p>
          This table compares <%= fuel_types %> <%= direction %> between this year to date
          (defined as ‘last year’ in the table below) and the corresponding period
          from the year before (defined as ‘previous year’).
        </p>
      )

      ERB.new(text).result(binding)
    end

    def varying_directions(list, in_list = true)
      text = %q(
        <%= in_list ? 't' : 'T'%>he kWh, CO2, £ values can move in opposite directions and by
        different percentages because the following may vary between
        the two years:
        <%= to_bulleted_list(list) %>
      )

      ERB.new(text).result(binding)
    end

    def electric_and_gas_mix
      %q( the mix of electricity and gas )
    end

    def carbon_intensity
      %q( the carbon intensity of the electricity grid )
    end

    def day_night_tariffs
      %q(
        the proportion of electricity consumed between night and day for schools
        with differential tariffs (economy 7)
      )
    end

    def only_in_previous_column
      %q(
        data only appears in the 'previous year' column if two years
        of data are available for the school
      )
    end

    def to_bulleted_list(list)
      text = %q(
        <ul>
          <%= list.map { |li| "<li>#{li}</li>" }.join('') %>
        </ul>
      )

      ERB.new(text).result(binding)
    end

    def cost_solar_pv
      %q(
        the cost column for schools with solar PV only represents the cost of consumption
        i.e. mains plus electricity consumed from the solar panels using a long term economic value.
        It doesn't use the electricity or solar PV tariffs for the school
      )
    end

    def solar_pv_electric_calc
      %q(
        the electricity consumption for schools with solar PV is the total
        of electricity consumed from the national grid plus electricity
        consumed from the solar PV (self-consumption)
        but excludes any excess solar PV exported to the grid
      )
    end

    def sheffield_estimate
      %q(
        self-consumption is estimated where we don't have metered solar PV,
        and so the overall electricity consumption will also not be 100% accurate,
        but will be a ‘good’ estimate of the year on year change
      )
    end

    def storage_heater_comparison
      %q(
        The electricity consumption also excludes storage heaters
        which are compared in a separate comparison
      )
    end

    def colder
      %q(
        <p>
          The &apos;adjusted&apos; columns are adjusted for difference in
          temperature between the two years. So for example, if the previous year was colder
          than last year, then the adjusted previous year gas consumption
          in kWh is adjusted to last year&apos;s temperatures and would be smaller than
          the unadjusted previous year value. The adjusted percent change is a better
          indicator of the work a school might have done to reduce its energy consumption as
          it&apos;s not dependent on temperature differences between the two years.
        </p>
      )
    end
  end 
  #=======================================================================================
  class BenchmarkChangeInEnergySinceLastYear < BenchmarkAnnualChangeBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_energy_since_last_year.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')
      ERB.new(text).result(binding)
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      # content2 = full_co2_breakdown(school_ids: school_ids, filter: filter)
      # content3 = full_energy_breakdown(school_ids: school_ids, filter: filter)
      content1 # + content2 + content3
    end

    private

    def full_co2_breakdown(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :change_in_co2_emissions_since_last_year_full_table, filter: filter)
    end

    def full_energy_breakdown(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :change_in_energy_since_last_year_full_table, filter: filter)
    end
  end
  #=======================================================================================
  class BenchmarkChangeInElectricitySinceLastYear < BenchmarkAnnualChangeBase
    include BenchmarkingNoTextMixin

    # some text duplication with the BenchmarkChangeInEnergySinceLastYear class
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_electricity_since_last_year.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkChangeInGasSinceLastYear < BenchmarkAnnualChangeBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_gas_since_last_year.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')

      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkChangeInStorageHeatersSinceLastYear < BenchmarkAnnualChangeBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_storage_heaters_since_last_year.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkChangeInSolarPVSinceLastYear < BenchmarkAnnualChangeBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_solar_pv_since_last_year.introduction_text_html')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  module BenchmarkPeriodChangeBaseElectricityMixIn
    def current_variable;     :current_pupils   end
    def previous_variable;    :previous_pupils  end
    def variable_type;        :pupils           end
    def has_changed_variable; :pupils_changed   end

    def change_variable_description
      'number of pupils'
    end

    def has_possessive
      'have'
    end

    def fuel_type_description
      'electricity'
    end
  end

  module BenchmarkPeriodChangeBaseGasMixIn
    def current_variable;     :current_floor_area   end
    def previous_variable;    :previous_floor_area  end
    def variable_type;        :m2                   end
    def has_changed_variable; :floor_area_changed   end

    def change_variable_description
      'floor area'
    end

    def has_possessive
      'has'
    end

    def fuel_type_description
      'gas'
    end
  end

  class BenchmarkPeriodChangeBase < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    def content(school_ids: nil, filter: nil, user_type: nil)
      @rate_changed_in_period = calculate_rate_changed_in_period(school_ids, filter, user_type)
      super(school_ids: school_ids, filter: filter)
    end

    private

    def footnote(school_ids, filter, user_type)
      raw_data = benchmark_manager.run_table_including_aggregate_columns(asof_date, page_name, school_ids, nil, filter, :raw, user_type)
      rows = raw_data.drop(1) # drop header

      return '' if rows.empty?

      floor_area_or_pupils_change_rows = changed_rows(rows, has_changed_variable)

      infinite_increase_school_names = school_names_by_calculation_issue(rows, :percent_changed, +Float::INFINITY)
      infinite_decrease_school_names = school_names_by_calculation_issue(rows, :percent_changed, -Float::INFINITY)

      changed = !floor_area_or_pupils_change_rows.empty? ||
                !infinite_increase_school_names.empty? ||
                !infinite_decrease_school_names.empty? ||
                @rate_changed_in_period


      text = %(
        <% if changed %>
          <p> 
            Notes:
            <ul>
              <% if !floor_area_or_pupils_change_rows.empty? %>
                <li>
                  (*1) the comparison has been adjusted because the <%= change_variable_description %>
                      <%= has_possessive %> changed between the two <%= period_types %> for
                      <%= floor_area_or_pupils_change_rows.map { |row| change_sentence(row) }.join(', and ') %>.
                </li>
              <% end %>
              <% if !infinite_increase_school_names.empty? %>
                <li>
                  (*2) schools where percentage change
                      is +Infinity is caused by the <%= fuel_type_description %> consumption
                      in the previous <%= period_type %> being more than zero
                      but in the current <%= period_type %> zero
                </li>
              <% end %>
              <% if !infinite_decrease_school_names.empty? %>
                <li>
                  (*3) schools where percentage change
                      is -Infinity is caused by the <%= fuel_type_description %> consumption
                      in the current <%= period_type %> being zero
                      but in the previous <%= period_type %> it was more than zero
                </li>
              <% end %>
              <% if @rate_changed_in_period %>
                <li>
                  (*6) schools where the economic tariff has changed between the two periods,
                       this is not reflected in the &apos;<%= BenchmarkManager.ch(:change_£current) %>&apos;
                       column as it is calculated using the most recent tariff.
                </li>
              <% end %>
            </ul>
          </p>
        <% end %>
      )
      ERB.new(text).result(binding)
    end

    def calculate_rate_changed_in_period(school_ids, filter, user_type)
      col_index = column_headings(school_ids, filter, user_type).index(:tariff_changed_period)
      return false if col_index.nil?

      data = raw_data(school_ids, filter, user_type)
      return false if data.nil? || data.empty?

      rate_changed_in_periods = data.map { |row| row[col_index] }

      rate_changed_in_periods.any?
    end

    def list_of_school_names_text(school_name_list)
      if school_name_list.length <= 2
        school_name_list.join(' and ')
      else
        (school_name_list.first school_name_list.size - 1).join(' ,') + ' and ' + school_name_list.last
      end 
    end

    def school_names_by_calculation_issue(rows, column_id, value)
      rows.select { |row| row[table_column_index(column_id)] == value }
    end

    def school_names(rows)
      rows.map { |row| remove_references(row[table_column_index(:school_name)]) }
    end

    # reverses def referenced(name, changed, percent) in benchmark_manager.rb
    def remove_references(school_name)
      puts "Before #{school_name} After #{school_name.gsub(/\(\*[[:blank:]]([[:digit:]]+,*)+\)/, '')}"
      school_name.gsub(/\(\*[[:blank:]]([[:digit:]]+,*)+\)/, '')
    end

    def changed_variable_column_index(change_variable)
      table_column_index(change_variable)
    end

    def changed?(row, change_variable)
      row[changed_variable_column_index(change_variable)] == true
    end

    def changed_rows(rows, change_variable)
      rows.select { |row| changed?(row, change_variable) }
    end

    def no_changes?(rows,  change_variable)
      rows.all?{ |row| !changed?(row, change_variable) }
    end

    def change_sentence(row)
      school_name = remove_references(row[table_column_index(:school_name)])
      current     = row[table_column_index(current_variable) ].round(0)
      previous    = row[table_column_index(previous_variable)].round(0)

      text = %(
        <%= school_name %>
        from <%= FormatEnergyUnit.format(variable_type, current, :html) %>
        to <%= FormatEnergyUnit.format(variable_type, previous, :html) %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInElectricityConsumptionSinceLastSchoolWeek < BenchmarkPeriodChangeBase
    include BenchmarkPeriodChangeBaseElectricityMixIn

    def period_type
      'school week'
    end

    def period_types
      "#{period_type}s" # pluralize
    end

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_electricity_consumption_recent_school_weeks.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkHolidaysChangeBase < BenchmarkPeriodChangeBase
    def period_type
      'holiday'
    end

    def period_types
      "#{period_type}s" # pluralize
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInElectricityBetweenLast2Holidays < BenchmarkHolidaysChangeBase
    include BenchmarkPeriodChangeBaseElectricityMixIn
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_electricity_holiday_consumption_previous_holiday.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInElectricityBetween2HolidaysYearApart < BenchmarkHolidaysChangeBase
    include BenchmarkPeriodChangeBaseElectricityMixIn
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_electricity_holiday_consumption_previous_years_holiday.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInGasConsumptionSinceLastSchoolWeek < BenchmarkHolidaysChangeBase
    include BenchmarkPeriodChangeBaseGasMixIn

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_gas_consumption_recent_school_weeks.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInGasBetweenLast2Holidays < BenchmarkHolidaysChangeBase
    include BenchmarkPeriodChangeBaseGasMixIn

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_gas_holiday_consumption_previous_holiday.introduction_text_html')
      text +=  I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInGasBetween2HolidaysYearApart < BenchmarkHolidaysChangeBase
    include BenchmarkPeriodChangeBaseGasMixIn

    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.change_in_gas_holiday_consumption_previous_years_holiday.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.comparison_with_previous_period_infinite')
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkHeatingHotWaterOnDuringHolidayBase < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This chart shows the projected <%= fuel %> costs for the current holiday.
          No comparative data will be shown once the holiday is over. The projection
          calculation is based on the consumption patterns during the holiday so far.
        </p>
      )
      ERB.new(text).result(binding)
    end
  end

  class BenchmarkElectricityOnDuringHoliday < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.electricity_consumption_during_holiday.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.es_exclude_storage_heaters_and_solar_pv_data_html')
      ERB.new(text).result(binding)
    end
  end

  class BenchmarkGasHeatingHotWaterOnDuringHoliday < BenchmarkHeatingHotWaterOnDuringHolidayBase
    include BenchmarkingNoTextMixin
    def introduction_text
      I18n.t('analytics.benchmarking.content.gas_consumption_during_holiday.introduction_text_html')
    end
    def fuel; 'gas' end
  end

  class BenchmarkStorageHeatersOnDuringHoliday < BenchmarkHeatingHotWaterOnDuringHolidayBase
    include BenchmarkingNoTextMixin
    def introduction_text
      I18n.t('analytics.benchmarking.content.storage_heater_consumption_during_holiday.introduction_text_html')
    end
    def fuel; 'storage heeaters' end
  end
  #=======================================================================================
  class BenchmarkEnergyConsumptionInUpcomingHolidayLastYear < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.holiday_usage_last_year.introduction_text_html')
      text += I18n.t('analytics.benchmarking.caveat_text.covid_lockdown')
      ERB.new(text).result(binding)
    end
  end
#=======================================================================================
  class BenchmarkChangeAdhocComparison < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = I18n.t('analytics.benchmarking.content.layer_up_powerdown_day_november_2022.introduction_text_html')
      ERB.new(text).result(binding)
    end

    # combine content of 4 tables: energy, electricity, gas, storage heaters
    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = electricity_content(school_ids: school_ids, filter: filter)
      content3 = gas_content(school_ids: school_ids, filter: filter)
      content4 = storage_heater_content(school_ids: school_ids, filter: filter)
      content1 + content2 + content3  + content4
    end

    private

    def electricity_content(school_ids:, filter:)
      extra_content(:layer_up_powerdown_day_november_2022_electricity_table, filter: filter)
    end

    def gas_content(school_ids:, filter:)
      extra_content(:layer_up_powerdown_day_november_2022_gas_table, filter: filter)
    end

    def storage_heater_content(school_ids:, filter:)
      extra_content(:layer_up_powerdown_day_november_2022_storage_heater_table, filter: filter)
    end
    
    def extra_content(type, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, type, filter: filter)
    end
  end

  class BenchmarkChangeAdhocComparisonElectricityTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin
  end

  class BenchmarkChangeAdhocComparisonGasTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      'The change columns are calculated using temperature adjusted values:'
    end
  end

  class BenchmarkChangeAdhocComparisonStorageHeaterTable < BenchmarkChangeAdhocComparisonGasTable
    include BenchmarkingNoTextMixin
  end

  #=======================================================================================
  class BenchmarkAutumn2022Comparison < BenchmarkChangeAdhocComparison
    def electricity_content(school_ids:, filter:)
      extra_content(:autumn_term_2021_2022_electricity_table, filter: filter)
    end
  
    def gas_content(school_ids:, filter:)
      extra_content(:autumn_term_2021_2022_gas_table, filter: filter)
    end
  
    def storage_heater_content(school_ids:, filter:)
      extra_content(:autumn_term_2021_2022_storage_heater_table, filter: filter)
    end
  end

  class BenchmarkAutumn2022ElectricityTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin
  end

  class BenchmarkAutumn2022GasTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      'The change columns are calculated using temperature adjusted values:'
    end
  end

  class BenchmarkAutumn2022StorageHeaterTable < BenchmarkChangeAdhocComparisonGasTable
    include BenchmarkingNoTextMixin
  end

  #=======================================================================================
  class BenchmarkSeptNov2022Comparison < BenchmarkChangeAdhocComparison

    def electricity_content(school_ids:, filter:)
      extra_content(:sept_nov_2021_2022_electricity_table, filter: filter)
    end
  
    def gas_content(school_ids:, filter:)
      extra_content(:sept_nov_2021_2022_gas_table, filter: filter)
    end
  
    def storage_heater_content(school_ids:, filter:)
      extra_content(:sept_nov_2021_2022_storage_heater_table, filter: filter)
    end
  end

  class BenchmarkSeptNov2022ElectricityTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin
  end

  class BenchmarkSeptNov2022GasTable < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      'The change columns are calculated using temperature adjusted values:'
    end
  end

  class BenchmarkSeptNov2022StorageHeaterTable < BenchmarkChangeAdhocComparisonGasTable
    include BenchmarkingNoTextMixin
  end

end
