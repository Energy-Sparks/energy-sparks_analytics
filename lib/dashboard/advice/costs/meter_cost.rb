# provides the costs (html, charts) on a single meter
# - year on year month comparison chart
# - billing table, grouped by month, with comparison versus last year
# - meter tariffs
class MeterCost
  class UnexpectedRequestForTwoYearsData < StandardError; end
  def initialize(school, meter, show_tariffs, aggregated, aggregate_start_date, aggregate_end_date)
    @school = school
    @meter = meter
    @show_tariffs = show_tariffs
    @aggregated = aggregated
    @aggregate_start_date = aggregate_start_date
    @aggregate_end_date = aggregate_end_date
    @meter_start_date = [meter.amr_data.start_date, aggregate_start_date].max
    @meter_end_date   = [meter.amr_data.end_date,   aggregate_end_date].min
  end

  def content
    {
      title:    summary,
      content:  [
                  intro_to_meter,
                  term_dependent_content,
                  agreed_supply_capacity_assessment,
                  tariff_information
                ].flatten
    }
  end

  def percent_real
    @percent_real ||= calculate_percent_real
  end

  private

  def summary
    meter_description + ": #{incomplete_coverage}" + meter_cost_and_time_description
  end

  def all_real_tariffs?(start_date, end_date)
    percent_real > 0.99
  end

  def calculate_percent_real
    count = missing_billing_periods.values.count { |missing| missing }
    count.to_f / (@meter_end_date - @meter_start_date + 1)
  end

  def fully_real_tariff?(type)
    type == false && type != :mixed
  end

  def accounting_tariff
    @meter.amr_data.accounting_tariff
  end

  def incomplete_coverage
    coverage = ''
    coverage += " from #{@meter.amr_data.start_date.strftime('%d-%m-%Y')}" if @meter.amr_data.start_date > @aggregate_start_date
    coverage += " to #{@meter.amr_data.end_date.strftime('%d-%m-%Y')}" if @meter.amr_data.end_date != @aggregate_end_date
    coverage
  end

  def term_dependent_content
    cc =  []
    cc += year_on_year_comparison if days_meter_data > 12 * 31
    cc += breakdown_charges(days_meter_data)
    cc
  end

  def breakdown_charges(days)
    if days < 14
      up_to_fourteen_day_breakdown
    elsif days < 8 * 10
      up_to_ten_week_breakdown
    else
      up_to_one_year_breakdown
    end
  end

  def year_on_year_comparison
    [
      intro_to_chart_2_year_comparison,
      chart_2_year_comparison,
      change_in_usage_description_html
    ]
  end

  def up_to_one_year_breakdown
    [
      intro_to_1_year_brokendown_chart,
      chart_1_year_breakdown,
      intro_to_cost_table,
      cost_table,
      intro_to_1_year_brokendown_pie_chart,
      pie_chart_breakdown
    ]
  end

  def up_to_ten_week_breakdown
    [
      intro_to_less_than_one_years_data,
      chart_breakdown_by_week
    ]
  end

  def up_to_fourteen_day_breakdown
    [
      intro_to_less_than_one_years_data,
      chart_breakdown_by_day
    ]
  end

  def tariff_information
    @show_tariffs ? [tariff_introduction_html, tariffs] : []
  end

  def agreed_supply_capacity_assessment
    AgreedSupplyCapacityAdvice.new(@meter).advice
  end

  def days_meter_data
    @meter.amr_data.days
  end

  def intro_to_meter
    text =  if all_real_tariffs?(@meter_start_date, @meter_end_date)
              %{
                <p>
                  The information below provides a good estimate of your annual
                  costs for this meter based on meter tariff information which
                  has been provided to Energy Sparks.
                </p>
              }
            else
              %{
                <p>          
                  Energy Sparks currently doesn't have a complete record of your real tariffs
                  and is using default tariffs between <%= group_missing_tariffs_text %>, 
                  which means your billing won't be accurate. To edit your tariffs go to the
                  'Manage School' drop down menu above and select 'Manage tariffs'.
                  If you would like to help us setup your billing correctly,
                  please get in touch by mailing
                  <a href="mailto:hello@energysparks.uk?subject=Meter%20tariff%20information%20for%20<%= @school.name %>">mailto:hello@energysparks.uk</a>.                    
                </p>
              }
            end

    { type: :html, content: ERB.new(text).result(binding) }
  end

  def intro_to_chart_2_year_comparison
    text = %{
      <h2>Comparison of last 2 years costs for this <%= @meter.fuel_type.to_s %> meter</h2>
      <p>
        This first chart compares your monthly consumption over the last 2 years
      </p>
    }
    { type: :html, content: ERB.new(text).result(binding) }
  end

  def intro_to_1_year_brokendown_chart
    text = %{
      <h2>Your last year's <%= @meter.fuel_type.to_s %> bill components</h2>
      <p>
      Last year's bill components were as follows:
      </p>
    }
    { type: :html, content: ERB.new(text).result(binding) }
  end

  def intro_to_1_year_brokendown_pie_chart
    text = %{
      <p>
        Last year's bill components were broken down as follows:
      </p>
    }
    { type: :html, content: text }
  end

  def intro_to_less_than_one_years_data
    text = %{
      <p>
        We only have <%= timescale_description %> of meter readings
        for this meter at the moment, so can't provide a year on year
        comparison.
      </p>
      <p>
        This is how your bill is currently broken down between its
        different components:
      </p>
    }
    html = ERB.new(text).result(binding)
    { type: :html, content: html }
  end

  def timescale_description
    FormatEnergyUnit.format(:years, days_meter_data / 365.0, :html)
  end

  def chart_2_year_comparison
    run_chart_for_meter(:electricity_cost_comparison_last_2_years_accounting)
  end

  def chart_1_year_breakdown
    run_chart_for_meter(:electricity_cost_1_year_accounting_breakdown)
  end

  def pie_chart_breakdown
    run_chart_for_meter(:pie_chart_1_year_accounting_breakdown)
  end

  def chart_breakdown_by_week
    run_chart_for_meter(:electricity_cost_1_year_accounting_breakdown_group_by_week)
  end

  def chart_breakdown_by_day
    run_chart_for_meter(:electricity_cost_1_year_accounting_breakdown_group_by_day)
  end

  def run_chart_for_meter(chart_name)
    AdviceBase.meter_specific_chart_config(chart_name, @meter.mpxn)
  end

  def intro_to_cost_table
    { type: :html, content: 'This is the same information in tabular form:' }
  end

  def cost_table
    monthly = MeterMonthlyCostsAdvice.new(@school, @meter)
    { type: :html,  content: monthly.two_year_monthly_comparison_table_html }
  end

  def tariffs
    { type: :html,  content: FormatMeterTariffs.new(@school, @meter, @meter_start_date, @meter_end_date).tariff_information_html }
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
      text
    end
  end

  def meter_cost_and_time_description
    data = meter_up_to_annual_cost
    "<span class='float-right'>#{data[:formatted_£]} (#{data[:formatted_years]})</span>"
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

  def general_usage_change_description(annual_change_abs_formatted, percent)
    return 'This is the same as last year.' if percent == 0.0 # unlikely
    text = %{
      <%= adjective_general(percent) %> last year of <%= annual_change_abs_formatted %>
    }
    ERB.new(text).result(binding)
  end

  def adjective_general(percent)
    if percent == 0.0
      'the same as'
    elsif percent > 0.01
      'an increase on'
    elsif percent > 0.0
      'a slight increase on'
    elsif percent < -0.01
      'a decrease on'
    else
      'a slight decrease on'
    end
  end

  def change_in_usage_description
    return '' unless two_years_data?

    current_year  = calculate_historic_values_html(0)
    previous_year = calculate_historic_values_html(-1)

    annual_increase_kwh = current_year[:kwh] - previous_year[:kwh]
    annual_increase_£ = current_year[:£] - previous_year[:£]

    annual_increase_kwh_abs_html =  FormatEnergyUnit.format(:kwh, annual_increase_kwh.magnitude, :html)
    annual_increase_£_abs_html   =  FormatEnergyUnit.format(:£,   annual_increase_£.magnitude,   :html)

    text = %{
      This year this meter consumed <%= current_year[:formatted_kwh] %>
      which cost <%= current_year[:formatted_£] %>,
      compared with <%= previous_year[:formatted_kwh] %> / <%= previous_year[:formatted_£] %>
      during the previous year.
      This is 
      <%= general_usage_change_description(annual_increase_£_abs_html, annual_increase_£) %>,
      and
      <%= general_usage_change_description(annual_increase_kwh_abs_html, annual_increase_kwh) %>
      in energy consumption.
    }.freeze
    ERB.new(text).result(binding)
  end

  def missing_billing_periods
    @missing_billing_periods ||= calculate_missing_billing_periods
  end

  def calculate_missing_billing_periods
    count = (billing_calculation_start_date..@meter_end_date).to_a.map do |date|
      # these are tristate true, false and :mixed (combined meters)
      cost = accounting_tariff.one_days_cost_data(date)
      [
        date,
        fully_real_tariff?(cost.system_wide) && fully_real_tariff?(cost.default)
      ]
    end.to_h
  end

  def group_missing_tariffs_text
    # split periods of real and non-real default system-wide tariffs
    grouped_periods = missing_billing_periods.to_a.slice_when do |prev, curr|
      prev[1] != curr[1]
    end

    # select only the non-real default system-wide tariffs
    missing = grouped_periods.select { |period| period[0][1] == false }

    # format
    missing.map do |period|
      sd = period.first[0].strftime('%d-%m-%Y')
      ed = period.last[0].strftime('%d-%m-%Y')
      "#{sd} and #{ed}"
    end.join(', ')
  end

  def billing_calculation_start_date
    twenty_five_months = 30 + 2 * 365 # approx 25 months, covers billing period of comparison chart and table
    [@meter_end_date - twenty_five_months, @meter_start_date].max
  end
end
