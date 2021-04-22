# provides the costs (html, charts) on a single meter
# - year on year month comparison chart
# - billing table, grouped by month, with comparison versus last year
# - meter tariffs
class MeterCost
  def initialize(school, meter)
    @school = school
    @meter = meter
  end

  def content
    {
      title:    summary,
      content:  [
        chart_2_year_comparison,
        chart_1_year_breakdown,
        cost_table,
        tariffs,
      ].flatten
    }
  end

  private

  def summary
    meter_description + ": " + meter_cost_and_time_description
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
      { type: :chart_name, content: chart_name, mpan_mprn: @meter.mpxn } # LEIGH this is the change asof 22Apr2021
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
      { type: :chart_data, data: data }
    ]
  end

  def cost_table
    monthly = MeterMonthlyCostsAdvice.new(@school, @meter)
    { type: :html,  content: monthly.two_year_monthly_comparison_table_html } 
  end

  def tariffs
    { type: :html,  content: FormatMeterTariffs.new(@school, @meter).tariff_information_html }
  end

  def got_here(n)
    { type: :html,  content: "<h1>Got here #{n}</h1>" } 
  end

  def meter_description
    text = "Meter #{@meter.mpxn}"
    text += " #{@meter.name}" unless @meter.name.empty?
    text
  end

  def meter_cost_and_time_description
    data = meter_up_to_annual_cost
    "#{data[:formatted_£]} (#{data[:formatted_years]}"
  end

  def meter_up_to_annual_cost
    start_date = [@meter.amr_data.end_date - 365, @meter.amr_data.start_date].max
    # not necessarily 100% consistent with monthly tables due to date boundaries
    £ = @meter.amr_data.kwh_date_range(start_date, @meter.amr_data.end_date, :accounting_cost)
    days = @meter.amr_data.end_date - start_date + 1
    {
      £:                £,
      formatted_£:      FormatEnergyUnit.format(:£, £, :html, false, false, :approx_accountant),
      days:             days,
      formatted_years:  FormatEnergyUnit.format(:years, days / 365.0, :html)
    }
  end
end
