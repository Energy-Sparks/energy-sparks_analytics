# extension of DashboardEnergyAdvice CO2 Advice Tab
# NB clean HTML from https://word2cleanhtml.com/cleanit
class DashboardEnergyAdvice

  def self.financial_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :electricity_by_month_year_0_1_finance_advice, :acc1
      FinancialAdviceIntroduction.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_cost_comparison_last_2_years_accounting, :acc2
      FinancialAdvice2YearCostComparisonText.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_cost_1_year_accounting_breakdown, :acc3
      FinancialAdviceElectricity2YearComparison.new(school, chart_definition, chart_data, chart_symbol)
    when :accounting_cost_daytype_breakdown_electricity, :acc4
      FinancialAdviceEasySavingsElectricity.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_by_month_year_0_1_finance_advice
      FinancialAdviceGasCostsIntroduction.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_cost_comparison_last_2_years_accounting
      FinancialAdviceGas2YearComparison.new(school, chart_definition, chart_data, chart_symbol)
    when :accounting_cost_daytype_breakdown_gas
      FinancialAdviceEasySavingsGas.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class FinancialAdviceBase < DashboardChartAdviceBase
    def initialize(chart_type, school, chart_definition, chart_data, advice_function = :co2)
      super(chart_type, school, chart_definition, chart_data)
      @advice_function = advice_function
    end

    def generate_advice
      if advice_valid?
        generate_valid_advice
      else
        header_template = %{
          <%= @body_start %>
            <p>
              <strong>This chart and advice are not relevent for this meter whose function is <%= meter_function_description %></strong>
            </p>
          <%= @body_end %>
        }.gsub(/^  /, '')

        @header_advice = generate_html(header_template, binding)

        @footer_advice = nil_advice
      end
    end

    def erb_bind(text)
      ERB.new(text).result(binding)
    end
    
    protected

    def adjective(percent_increase)
      percent_increase.between?(-0.05, 0.05) ? 'about the same' : (percent_increase > 0.0 ? 'increase' : 'decrease')
    end

    def above_below_benchmark_comparison_adjective(percent, benchmark)
      return 'about the same as' if (percent - benchmark).between?(-0.05, 0.05) 
      benchmark - percent > 0.0 ? 'better than' : 'below'
    end

    def meter_function_description
      @heat_meter.non_heating_only? ? 'non heating only' : (@heat_meter.heating_only? ? 'heating only' : 'heating and non heating')
    end

    def generate_valid_advice
      EnergySparksAbstractBaseClass.new('Call to heating model fitting advice base class not expected')
    end

    def advice_valid?
      true
    end

    def concatenate_advice_with_body_start_end(advice_list)
      advice_list = [ advice_list ] unless advice_list.is_a?(Array)
      template =  %q{ <%= @body_start %> } +
                  advice_list.join(' ') +
                  %q{ <%= @body_end %> }
                  
      template.gsub(/^  /, '')
    end

    def meter_tariff_completeness_advice(aggregate_meter, meters)
      end_date = aggregate_meter.amr_data.end_date
      ideal_start_date = end_date - 2 * 365
      start_date = [ideal_start_date, aggregate_meter.amr_data.start_date].max
      percent_coverage = MeterTariffs.accounting_tariff_availability_coverage(start_date, end_date, meters)
      percent_coverage_html = FormatEnergyUnit.format(:£, percent_coverage, :html)
      if percent_coverage >= 0.99
        %q(
          We have complete meter tariff information for your school
          so this information should be reasonably accurate. However,
          first time you use this page you should cross reference
          the information provided with your bills and let us know
          if there are descrepancies?
        )
      elsif percent_coverage <= 0.01
        %q(
          We have no up to date tariff information for your school,
          so this page is only an estimate based on default information
          and you should assume is not accurate.
        )
      else
        text = %(
          We have  <%= percent_coverage_html %> of the tariff information we need for your school,
          so this page is only an estimate based on default information
          and you should assume is not accurate.
        )
        generate_html(text, binding)
      end
    end

    INTRO_TO_SCHOOL_FINANCES_1 = %q(
      <p>
        Energy Sparks calculates electricity and gas costs using 2 different
        methods:
      </p>
      <p>
        1. <strong>Economic Costs</strong>:
      </p>
        <ul>
          <li>
            this assumes a simple cost model, with electricity costing 15p/kWh
            and gas 3p/kWh
          </li>
          <li>
            generally, this method is used when information is presented to
            pupils because it is easy to understand, and allows them to do simple maths
            converting between kWh and &#163;
          </li>
          <li>
            we also use it for economic forecasting, when doing cost benefit
            analysis for suggested improvements to your energy management, as it better
            represents future energy prices/tariffs than your current potentially
            volatile tariffs as these can change from year to year
          </li>
        </ul>
      <p>
        2. <strong>Accounting Costs</strong>:
      </p>
          <ul>
            <li>
              These represent your real energy costs and represent all the
              different types of standing charges applied to your account
            </li>
            <li>
              To do this we need to know what these tariffs are, sometimes these
              can be provided by all schools by a local authority, and sometimes you will
              need to provide us the information is not available from the Local
              Authority. MAT or Energy Supplier
            </li>
            <li>
              We can use this more accurate tariff information to provide more
              detailed advice on potential cost savings through tariff changes or meter
              consolidation
            </li>
          </ul>
    ).freeze

    INSTRUCTIONS_IF_ACCOUNTING_TARIFF_INFORMATION_MISSING = %q(
      <p>
        Unfortunately, we don't have detailed meter information for these meters
        <%= missing_accounting_tariff_meter_mpan_mprn_text %>
        so we are using defaults for your area. Could you
        <a href="mailto:hello@energysparks.uk?subject=Meter%20tariff%20information%20for%20<%= @school.name %>">contact us</a>
        and let us know your current tariffs and we can set them up so the
        information on this page is accurate? This will also allow us to analyse
        your tariff to see if there are opportunities for cost reduction.
      </p>
    ).freeze

    def meter_intro(aggregate_meter, meters)
      info = meter_tariff_completeness_advice(aggregate_meter, meters)
      text = %(
        <hr>
        <h2>Accounting tariff Information for your school</h2>
        <p> <%= info %></p>
      )
      generate_html(text, binding)
    end

    INTRODUCTION_TO_2_YEAR_ELECTRICITY_COMPARISON_CHART = %q(
      <br>
      <h2>
          Summary of your annual costs
      </h2>
      <h3>
          Electricity
      </h3>
      <p>
          The chart below shows a comparison of your total electricity usage over the
          last 2 years (across all electricity meters) in kWh:
      </p>
    ).freeze

    private def missing_accounting_tariffs_meters
      meters = @school.real_meters
      meters.select do |meter|
        tariff = meter.meter_tariffs.accounting_tariff_for_date(meter.amr_data.end_date)&.tariff
        tariff.nil? || tariff[:default]
      end
    end

    private def missing_accounting_tariff_meter_mpan_mprn_text
      meters = missing_accounting_tariffs_meters
      return nil if meters.empty?
      list_of_meter_texts = meters.map { |meter| "#{meter.fuel_type}: #{meter.mpan_mprn}" }
      list_of_meter_texts.join(', ')
    end

    private def missing_accounting_tariff_text
      return '' if missing_accounting_tariffs_meters.empty?
      INSTRUCTIONS_IF_ACCOUNTING_TARIFF_INFORMATION_MISSING
    end
  end

  class FinancialAdviceIntroduction < FinancialAdviceBase
    include Logging

    def generate_valid_advice

      electricity_meter_tariff_tables = FormatMetersTariffs.new(@school).tariff_tables_html(@school.electricity_meters)

      header_template = concatenate_advice_with_body_start_end(
        [
          INTRO_TO_SCHOOL_FINANCES_1,
          meter_intro(@school.aggregated_electricity_meters, @school.electricity_meters),
          electricity_meter_tariff_tables,
          missing_accounting_tariff_text,
          INTRODUCTION_TO_2_YEAR_ELECTRICITY_COMPARISON_CHART
        ]
      )

      @header_advice = generate_html(header_template, binding)

      footer_template = %q(
        <p>
          You can use the chart to quickly assess changes in electricity your electricity usage.
        </p>
      ).freeze

      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class FinancialAdvice2YearCostComparisonText < FinancialAdviceBase
    def generate_valid_advice
      header_template = %q(
        <p>
          This first chart compares your monthly consumption
          over the last 2 years.
        </p>
      ).freeze

      @header_advice = generate_html(header_template, binding)

      footer_template = %q(
      ).freeze

      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class FinancialAdviceGasCostsIntroduction < FinancialAdviceBase

    INTRODUCTION_TO_2_YEAR_GAS_COMPARISON_CHART = %q(
      <p>
        The chart below shows a comparison of your total
        gas usage over the last 2 years (across all gas meters):
      </p>
    ).freeze

    def generate_valid_advice
      gas_meter_tariff_tables = FormatMetersTariffs.new(@school).tariff_information_html(@school.heat_meters)

      header_template = concatenate_advice_with_body_start_end(
        [
          INTRO_TO_SCHOOL_FINANCES_1,
          meter_intro(@school.aggregated_heat_meters, @school.heat_meters),
          gas_meter_tariff_tables,
          missing_accounting_tariff_text,
          INTRODUCTION_TO_2_YEAR_GAS_COMPARISON_CHART
        ]
      )

      @header_advice = generate_html(header_template, binding)

      footer_template = %q(
        <p>
          You can use this chart to assess how much your gas usage
          has changed over the last 2 years.
        </p>
      ).freeze

      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class FinancialAdvice2YearComparison < FinancialAdviceBase
    include Logging

    protected def fuel_type
      raise EnergySparksAbstractBaseClass, 'Unexpected call to abstract base class'
    end

    TWO_YEAR_COMPARISON_CHART_BROKEN_DOWN_TO_STANDING_CHARGE_CHART_INFO = %q(
      <p>
        You can use the chart to quickly assess changes in <%= fuel_type %> costs.
      <p>
      <%= change_in_usage_description(fuel_type) %>
    ).freeze

    private def aggregate_meter_p_and_l_table

      ma = MeterMonthlyCostsAdvice.new(@school, meter)
      ma.two_year_monthly_comparison_table_html
      
=begin
      accounting_cost_data = ConvertTwoYearAccountingChartDataToTable.new(@school)
      header, £_formatted_monthly_p_and_l_rows, £_formatted_totals = accounting_cost_data.formatted_table(fuel_type)
      html_table(header, £_formatted_monthly_p_and_l_rows, £_formatted_totals) + months
=end
    end

    private def meter
      if fuel_type == :electricity
        return @school.aggregated_unaltered_electricity_meters
      elsif fuel_type == :gas
        return @school.aggregated_heat_meters
      else
        raise EnergySparksUnexpectedStateException, 'Unexpected null meter definition for financial advice chart calculations' if fuel_type.nil?
        raise EnergySparksUnexpectedStateException, "Unexpected meter definition #{fuel_type}for financial advice chart calculations"
      end
    end

    protected def annual_values(fuel_type, year_number)
      fuel_type = :allelectricity_unmodified if fuel_type == :electricity
      year_kwh = ScalarkWhCO2CostValues.new(@school).aggregate_value({year: year_number}, fuel_type, :kwh)
      year_£ = ScalarkWhCO2CostValues.new(@school).aggregate_value({year: year_number}, fuel_type, :accounting_cost)
      {
        kwh:     year_kwh,
        £:       year_£,
        formatted_kwh:   FormatEnergyUnit.format(:kwh, year_kwh, :html, false, false, :no_decimals),
        formatted_£:     FormatEnergyUnit.format(:£,   year_£,   :html, false, false, :no_decimals),
      }
    end

    protected def change_in_usage_description(fuel_type)
      current_year = nil
      previous_year = nil
      begin
        current_year = annual_values(fuel_type, 0)
        previous_year = annual_values(fuel_type, -1)
      rescue EnergySparksNotEnoughDataException => _e
        return ''
      end
      annual_increase_kwh = current_year[:kwh] - previous_year[:kwh]
      annual_increase_£ = current_year[:£] - previous_year[:£]

      percent_increase_kwh  = annual_increase_kwh / previous_year[:kwh]
      percent_increase_£    = annual_increase_£ / previous_year[:£]

      # because the underlying rates might have changed the £ and kWh adjectives can be different
      change_adjective_kwh  = adjective(percent_increase_kwh)
      change_adjective_£    = adjective(percent_increase_£)

      formatted_increase_kwh_percent = FormatEnergyUnit.format(:percent, percent_increase_kwh.magnitude, :html)
      abs_change_£ = FormatEnergyUnit.format(:£, annual_increase_£.magnitude, :html, false, false, :no_decimals)

      text = %q(
        This year you used <%= current_year[:formatted_kwh] %> of <%= fuel_type.to_s %>
        which cost <%= current_year[:formatted_£] %>, 
        compared with <%= previous_year[:formatted_kwh] %> / <%= previous_year[:formatted_£] %>
        during the previous year. This is an <%= change_adjective_kwh %> in usage of <%= formatted_increase_kwh_percent %>,
        and an <%= change_adjective_kwh %> in costs of <%= abs_change_£ %>.
      ).freeze
      generate_html(text, binding)
    end

    def generate_valid_advice
      @header_advice = generate_html(TWO_YEAR_COMPARISON_CHART_BROKEN_DOWN_TO_STANDING_CHARGE_CHART_INFO, binding)
      footer_template = %q(
        <p>
        This is the same information in tabular form:
        </p>
        <%= aggregate_meter_p_and_l_table %>
      ).freeze

      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class FinancialAdviceElectricity2YearComparison < FinancialAdvice2YearComparison
    protected def fuel_type
      :electricity
    end
  end

  class FinancialAdviceGas2YearComparison < FinancialAdvice2YearComparison
    protected def fuel_type
      :gas
    end
  end

  class FinancialAdviceEasySavingsBase < FinancialAdviceBase
    private def meters
      meters = @school.real_meters
      meters.select { |meter| meter.fuel_type == fuel_type }
    end

    private def year
      end_date = aggregate_meter.amr_data.end_date
      start_date = [aggregate_meter.amr_data.start_date, end_date - 365].max
      [start_date, end_date]
    end

    private def annual_standing_charge_for_meter_£(meter)
      aggregate_start_date, aggregate_end_date = year
      start_date = [aggregate_start_date, meter.amr_data.start_date].max
      end_date = [aggregate_end_date, meter.amr_data.end_date].min
      return 0.0 if start_date > end_date
      meter.amr_data.accounting_tariff.total_standing_charges_between_dates(start_date, end_date)
    end

    private def total_standing_charges
      standing_charges = meters.map { |meter| annual_standing_charge_for_meter_£(meter) }.sum
      standing_charges.nil? ? 0.0 : standing_charges # TODO(PH, 13Jan2020) - Low Carbon Hub schools have no real meters so produce nil
    end

    def generate_valid_advice
      timescale = { up_to_a_year: 0 }
      # SeriesNames [HOLIDAY.freeze, WEEKEND.freeze, SCHOOLDAYOPEN.freeze, SCHOOLDAYCLOSED.freeze].freeze
      total_cost_£ = ScalarkWhCO2CostValues.new(@school).aggregate_value(timescale, fuel_type, :accounting_cost)
      day_type_percent = ScalarkWhCO2CostValues.new(@school).day_type_breakdown(timescale, fuel_type, :kwh, false, true)
      out_of_hours_percent = 1.0 - day_type_percent[SeriesNames::SCHOOLDAYOPEN]
      formatted_out_of_hours_percent = FormatEnergyUnit.format(:percent, out_of_hours_percent, :html)
      variable_costs_£ = total_cost_£ - total_standing_charges
      saving_to_exemplar_percent = out_of_hours_percent - exemplar_out_of_hours_percent
      saving_£ = variable_costs_£ * saving_to_exemplar_percent

      formatted_saving_£ = FormatEnergyUnit.format(:£, saving_£.magnitude, :html)
      formatted_exemplar_out_of_hours_percent = FormatEnergyUnit.format(:percent, exemplar_out_of_hours_percent.magnitude, :html)
      formatted_average_out_of_hours_percent = FormatEnergyUnit.format(:percent, average_out_of_hours_percent.magnitude, :html)

      adjective = above_below_benchmark_comparison_adjective(out_of_hours_percent, average_out_of_hours_percent)

      header_template = %q(
        <p>
        Your usage broken down by day, time of day is as follows:
        </p>
      ).freeze
      @header_advice = generate_html(header_template, binding)

      footer_template = %q(

        <p>
          It shows when you have used electricity over the past year.
          <%= formatted_out_of_hours_percent %> of your <%= fuel_type %> usage
          is out of hours: which is <%= adjective %> the average of <%= formatted_average_out_of_hours_percent %>. The
          best schools only consume <%= formatted_exemplar_out_of_hours_percent %> out of hours. Reducing your school's out of
          hours usage to <%= formatted_exemplar_out_of_hours_percent %> would save <%= formatted_saving_£ %>  per year, and is often
          the most cost effective way to save energy.
        </p>
      ).freeze

      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class FinancialAdviceEasySavingsElectricity < FinancialAdviceEasySavingsBase
    protected def fuel_type
      :electricity
    end

    protected def aggregate_meter
      @school.aggregated_electricity_meters
    end

    protected def exemplar_out_of_hours_percent
      0.35
    end

    protected def average_out_of_hours_percent
      0.5
    end
  end

  class FinancialAdviceEasySavingsGas < FinancialAdviceEasySavingsBase
    protected def fuel_type
      :gas
    end

    protected def aggregate_meter
      @school.aggregated_heat_meters
    end

    protected def exemplar_out_of_hours_percent
      0.25
    end

    protected def average_out_of_hours_percent
      0.5
    end
  end
end
