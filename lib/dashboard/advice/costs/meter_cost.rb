# provides the costs (html, charts) on a single meter
# - year on year month comparison chart
# - billing table, grouped by month, with comparison versus last year
# - meter tariffs
class MeterCost
  class UnexpectedRequestForTwoYearsData < StandardError; end
  def initialize(school, meter, show_tariffs, aggregated)
    @school = school
    @meter = meter
    @show_tariffs = show_tariffs
    @aggregated = aggregated
  end

  def content
    c = {
      title:    summary,
      content:  [
        intro_to_meter,
        intro_to_chart_2_year_comparison,
        chart_2_year_comparison,
        change_in_usage_description_html,
        intro_to_1_year_brokendown_chart,
        chart_1_year_breakdown,
        intro_to_cost_table,
        cost_table
      ].flatten
    }
    if @show_tariffs  # don't show tariffs if aggregate meter of multiple meters
      c[:content].push()
      c[:content].push()
    end
    c
  end

  private

  def summary
    meter_description + ": " + meter_cost_and_time_description
  end

  def intro_to_meter
    text = %{
      <p>
        The information below provides a good estimate of your annual
        costs for this meter based on meter tariff information which
        has been provided to Energy Sparks.
      </p>
    }
    { type: :html, content: text }
  end

  def intro_to_chart_2_year_comparison
    text = %{
      <p>
        <b>Comparison of last 2 years costs for this meter</b>
      </p>
      <p>
        This first chart compares your monthly consumption over the last 2 years
      </p>
    }
    { type: :html, content: text }
  end

  def intro_to_1_year_brokendown_chart
    text = %{
      <p>
        <b>Your last year's Electricity bill components</b>
      </p>
      <p>
      Last year's bill components were as follows:
      </p>
    }
    { type: :html, content: text }
  end

  def chart_2_year_comparison
    run_chart_for_meter(:electricity_cost_comparison_last_2_years_accounting)
  end

  def chart_1_year_breakdown
    run_chart_for_meter(:electricity_cost_1_year_accounting_breakdown)
  end

  def run_chart_for_meter(chart_name)
    chart_manager = ChartManager.new(@school)
    chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name].clone
    chart_config[:meter_definition] =  @meter.mpxn
    name = "#{chart_name}_#{@meter.mpxn}".to_sym
    data = chart_manager.run_chart(chart_config, name)
    [
      # { type: :chart, data: data },
      { type: :chart_config, data: chart_config },
      { type: :chart_data, data: data },
      { type: :chart_name, content: chart_name, mpan_mprn: @meter.mpxn }, # LEIGH this is the change asof 22Apr2021
      { type: :analytics_html, content: AdviceBase.highlighted_dummy_chart_name_html(name) } 
    ]
  end

  def run_chart_for_meter_deprecated(chart_name)
    chart_manager = ChartManager.new(@school)
    chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name].clone
    chart_config[:meter_definition] =  @meter.mpxn
    name = "#{chart_name}_#{@meter.mpxn}".to_sym
    data = chart_manager.run_chart(chart_config, name)
    [
      # { type: :chart, data: data },
      { type: :chart_config, data: chart_config },
      { type: :chart_data, data: data },
    ]
  end

  def intro_to_cost_table
    { type: :html, content: 'This is the same information in tabular form:' }
  end

  def cost_table
    monthly = MeterMonthlyCostsAdvice.new(@school, @meter)
    { type: :html,  content: monthly.two_year_monthly_comparison_table_html } 
  end

  def tariffs
    { type: :html,  content: FormatMeterTariffs.new(@school, @meter).tariff_information_html }
  end

  def tariff_introduction_html
    { type: :html,  content: "<h1>Your tariffs</h1>" } 
  end

  # Accordion summary says: 'Total:' - if aggregate meter and has underlying meters from which it sums
  def is_total_meter?
    @aggregated && !@show_tariffs
  end

  def meter_description
    if is_total_meter?
      "Total"
    else
      text = "Meter #{@meter.mpxn}"
      text += " #{@meter.name}" unless @meter.name.empty?
    end
  end

  def meter_cost_and_time_description
    data = meter_up_to_annual_cost
    "#{data[:formatted_£]} (#{data[:formatted_years]})"
  end

  def meter_up_to_annual_cost
    start_date = [@meter.amr_data.end_date - 365, @meter.amr_data.start_date].max
    # not necessarily 100% consistent with monthly tables due to date boundaries
    £ = @meter.amr_data.kwh_date_range(start_date, @meter.amr_data.end_date, :accounting_cost)
    days = @meter.amr_data.end_date - start_date + 1
    {
      £:                £,
      formatted_£:      FormatEnergyUnit.format_pounds(£, :html, :approx_accountant, true),
      days:             days,
      formatted_years:  FormatEnergyUnit.format(:years, days / 365.0, :html)
    }
  end

  def calculate_historic_values_html(year)
    raise UnexpectedRequestForTwoYearsData, 'Should not be called' unless two_years_data?
    end_date   = @meter.amr_data.end_date + year * 365
    start_date = end_date - 364

    kwh = @meter.amr_data.kwh_date_range(start_date, end_date, :kwh)
    £   = @meter.amr_data.kwh_date_range(start_date, end_date, :accounting_cost)

    {
      kwh:            kwh,
      £:              £,
      formatted_£:    FormatEnergyUnit.format(:£,   £,   :html),
      formatted_kwh:  FormatEnergyUnit.format(:kwh, kwh, :html)
    }
  end

  def two_years_data?
    @meter.amr_data.days >= (365 * 2)
  end

  def change_in_usage_description_html
    { type: :html, content: change_in_usage_description }
  end

  def change_in_usage_description
    return '' unless two_years_data?

    current_year  = calculate_historic_values_html(0)
    previous_year = calculate_historic_values_html(-1)

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
      This year you consumed <%= current_year[:formatted_kwh] %>
      which cost <%= current_year[:formatted_£] %>, 
      compared with <%= previous_year[:formatted_kwh] %> / <%= previous_year[:formatted_£] %>
      during the previous year. This is an <%= change_adjective_kwh %> in usage of <%= formatted_increase_kwh_percent %>,
      and an <%= change_adjective_kwh %> in costs of <%= abs_change_£ %>.
    ).freeze
    ERB.new(text).result(binding)
  end

  def adjective(percent_increase)
    percent_increase.between?(-0.05, 0.05) ? 'about the same' : (percent_increase > 0.0 ? 'increase' : 'decrease')
  end
end
