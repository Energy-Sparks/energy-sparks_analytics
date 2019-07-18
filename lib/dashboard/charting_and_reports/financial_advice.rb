require 'erb'
require_relative 'dashboard_analysis_advice'

# extension of DashboardEnergyAdvice CO2 Advice Tab
# NB clean HTML from https://word2cleanhtml.com/cleanit
class DashboardEnergyAdvice
  charts = %i[
    electricity_cost_comparison_last_2_years
    electricity_cost_comparison_last_2_years_accounting
    electricity_cost_comparison_last_2_years_accounting_breakdown
    electricity_cost_1_year_accounting_breakdown
    electricity_cost_comparison_1_year_accounting_breakdown_by_week
    gas_cost_comparison_1_year_accounting_breakdown_by_week
    gas_cost_comparison_1_year_economic_breakdown_by_week
    electricity_2_week_accounting_breakdown
    electricity_1_year_intraday_accounting_breakdown
    electricity_1_year_intraday_kwh_breakdown
    gas_1_year_intraday_accounting_breakdown
    gas_1_year_intraday_economic_breakdown
    gas_1_year_intraday_kwh_breakdown
  ]

  def self.financial_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :electricity_cost_comparison_last_2_years_accounting_breakdown
      FinancialAdviceIntroduction.new(school, chart_definition, chart_data, chart_symbol)
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

    protected

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
  end

  class ConvertTwoYearAccountingChartDataToTable
    def initialize(school)
      @school = school
    end

    def formatted_table(fuel_type)
      two_year_p_and_l(fuel_type)
      header, monthly_p_and_l_table, totals, £_columns = decode_monthly_data
      £_formatted_monthly_p_and_l_rows = format_month_rows(monthly_p_and_l_table, £_columns)
      £_formatted_totals = format_month_row(totals, £_columns)
      £_formatted_totals[0] = 'Total'
      [header, £_formatted_monthly_p_and_l_rows, £_formatted_totals]
    end

    def two_year_p_and_l(fuel_type = :electricity, meter = nil)
      @chart_data = run_chart(fuel_type, meter)
    end

    private def run_chart(fuel_type = :electricity, meter = nil)
      chart_config = chart_definition(fuel_type, meter)
      chart_manager = ChartManager.new(@school)
      @chart_data = chart_manager.run_chart(chart_config, :financial_advice_manual_config)
    end

    private def meter_definition(fuel_type, meter)
      if fuel_type.is_a?(Integer) # mpan or mprm for sub meter
        return fuel_type
      elsif !meter.nil?
        return meter.id
      elsif fuel_type == :electricity
        return :allelectricity
      elsif fuel_type == :gas
        return :allheat
      else
        raise EnergySparksUnexpectedStateException, 'Unexpected null meter definition for financial advice chart calculations' if fuel_type.nil?
        raise EnergySparksUnexpectedStateException, "Unexpected meter definition #{fuel_type}for financial advice chart calculations"
      end
    end

    private def chart_definition(fuel_type = :electricity, meter = nil)
      {
        name:             '2 year accounting: internal use only',
        chart1_type:      :column,
        series_breakdown: :accounting_cost,
        x_axis:           :month,
        meter_definition: meter_definition(fuel_type, meter),
        yaxis_scaling:    :none,
        yaxis_label:      :£,
        timescale:        [{ year: 0 }, { year: -1 }],
        yaxis_units:      :accounting_cost
      }
    end
    # cost data is held under the 'x_data' part fo the hash as a series of hashes
    # monthly values e.g.
    #     :x_data => {
    #            "standing_charge:Sun14May17-Sat12May18" => [
    #               [ 0] 7.585714285714287,
    #               [ 1] 12.642857142857137,
    #               ....
    #               [12] 5.057142857142857 # note 13th month => partial month at beginning and end
    # ],
    private def decode_monthly_data
      header = ['Month', rate_types_for_header, 'Total', 'Variance versus 17/18'].flatten
      £_columns = [false, Array.new(rate_types_for_header.length, true), true, true].flatten

      last_year_totals = year_totals(0)
      this_year_totals = year_totals(1)

      month_rows = Array.new(13) {Array.new(header.length, 0.0)}

      @chart_data[:x_axis].each_with_index do |month_description, month_index|
        month_rows[month_index][header.index('Month')] = month_description
        month_rows[month_index][header.index('Total')] = this_year_totals[month_index]
        variance = this_year_totals[month_index] - last_year_totals[month_index]
        month_rows[month_index][header.index('Variance versus 17/18')] = variance
        rate_types_for_header.each do |rate_type|
          month_rows[month_index][header.index(rate_type)] = rate(rate_type, month_index, 0)
        end
      end
      totals = totals_from_table(month_rows, £_columns)
      [header, month_rows, totals, £_columns]
    end

    private def totals_from_table(month_rows, columns_to_total)
      totals = columns_to_total.map { |total| total ? 0.0 : '' }
      month_rows.each do |month_row|
        columns_to_total.each_with_index do |total, index|
          totals[index] += month_row[index] if total
        end
      end
      totals
    end

    private def format_month_rows(month_rows, columns_to_convert_to_£)
      month_rows.map { |month_row| format_month_row(month_row, columns_to_convert_to_£) }
    end

    private def format_month_row(month_row, columns_to_convert_to_£)
      formatted_row = Array.new(columns_to_convert_to_£.length, '')
      columns_to_convert_to_£.each_with_index do |in_£s, index|
        formatted_row[index] += in_£s ? FormatEnergyUnit.format(:£, month_row[index], :html) : month_row[index]
      end
      formatted_row
    end

    private def rate(rate_type, month_index, year_index)
      key = key_for_rate_year(rate_type, year_index)
      @chart_data[:x_data][key][month_index] unless key.nil?
    end

    private def key_for_rate_year(rate_type, year_index)
      @chart_data[:x_data].keys.each do |composite_key|
        loop_rate_type, start_date, end_date = decode_month_chart_type_key(composite_key)
        dehumanized_rate_type = rate_type.downcase.squish.gsub(/\s/, '_').to_sym # not ideal
        return composite_key if year_key(start_date, end_date) == unique_years[year_index] && loop_rate_type == dehumanized_rate_type
      end
      nil
    end

    private def year_totals(year_index)
      totals = Array.new(13, 0.0)
      @chart_data[:x_data].each_with_index do |(composite_key, months_x13), month_index|
        rate_type, start_date, end_date = decode_month_chart_type_key(composite_key)
        if year_key(start_date, end_date) == unique_years[year_index]
          totals = [totals, months_x13].transpose.map {|x| x.reduce(:+)}
        end
      end
      totals
    end

    private def rate_types_for_header
      list_of_rate_types.map { |rate_type_sym| rate_type_sym.to_s.humanize }
    end

    private def year_key(start_date, end_date)
      start_date.strftime('%y') + '/' + end_date.strftime('%y')
    end

    private def unique_years
      year_list = []
      @chart_data[:x_data].keys.each do |composite_key|
        _rate_type, start_date, end_date = decode_month_chart_type_key(composite_key)
        year_list.push(year_key(start_date, end_date))
      end
      year_list.uniq.sort
    end

    private def list_of_rate_types
      @rate_types ||= @chart_data[:x_data].keys.map { |composite_key| decode_month_chart_type_key(composite_key)[0] }.uniq
    end

    # "standing_charge:Sun14May17-Sat12May18" becomes [:standing_charge, start_date, end_date]
    private def decode_month_chart_type_key(composite_key)
      return [composite_key, nil, nil] unless composite_key.include?(':')
      rate_type_key, date_range = composite_key.split(':')
      date1, date2 = date_range.split('-')
      [rate_type_key.to_sym, Date.parse(date1), Date.parse(date2)]
    end
  end

  class FinancialAdviceIntroduction < FinancialAdviceBase
    include Logging

    INTRO_TO_SCHOOL_FINANCES_1 = %q(
      <h1>
        School Energy Financial Costs
      </h1>
    ).freeze

    def aggregate_electricity_meter_p_and_l_table
      accounting_cost_data = ConvertTwoYearAccountingChartDataToTable.new(@school)
      header, £_formatted_monthly_p_and_l_rows, £_formatted_totals = accounting_cost_data.formatted_table(:electricity)
      html_table(header, £_formatted_monthly_p_and_l_rows, £_formatted_totals)
    end

    def aggregate_gas_meter_p_and_l_table
      accounting_cost_data = ConvertTwoYearAccountingChartDataToTable.new(@school)
      header, £_formatted_monthly_p_and_l_rows, £_formatted_totals = accounting_cost_data.formatted_table(:gas)
      html_table(header, £_formatted_monthly_p_and_l_rows, £_formatted_totals)
    end

    private def def p_and_l_tables_and_advice_for_all_meters
      electric = summary_p_and_l_tables_for_aggregate_and_any_subsidiary_meters(:electricity)
      gas = summary_p_and_l_tables_for_aggregate_and_any_subsidiary_meters(:gas)
      [electric, gas].join(' ')
    end

    private def summary_p_and_l_tables_for_aggregate_and_any_subsidiary_meters(fuel_type)
      if fuel_type == :electricity
        unless @school.aggregated_electricity_meters.nil?
          [
            %q( <h2>Total Electricity Costs</h2> ),
            aggregate_electricity_meter_p_and_l_table
          ].join(' ')
        end
      elsif fuel_type == :gas
        unless @school.aggregated_heat_meters.nil?
          [
            %q( <h2>Total Gas Costs</h2> ),
            aggregate_gas_meter_p_and_l_table
          ].join(' ')
        end
      else
        raise EnergySparksUnexpectedStateException, 'Unexpected unexpected fuel type for financial advice chart calculations'
      end
    end

    def generate_valid_advice
   
      header_template = concatenate_advice_with_body_start_end(
        [
          INTRO_TO_SCHOOL_FINANCES_1,
          summary_p_and_l_tables_for_aggregate_and_any_subsidiary_meters(:electricity),
          summary_p_and_l_tables_for_aggregate_and_any_subsidiary_meters(:gas)
        ]
      )

      @header_advice = generate_html(header_template, binding)

      @footer_advice = nil_advice
    end
  end
end
