
require_relative './advice_general.rb'
class AdviceBaseload < AdviceElectricityBase
  def baseload_one_year_chart
    @bdown_1year_chart ||= charts[0]
  end

  def baseload_one_year_chart_timescales
    self.class.chart_timescale_and_dates(baseload_one_year_chart)
  end

  def baseload_longterm_chart
    @bdown_longterm_chart ||= charts[1]
  end

  def baseload_benchmark_exemplar_chart
    charts[2]
  end

  def baseload_longterm_chart_timescales
    self.class.chart_timescale_and_dates(baseload_longterm_chart)
  end

  def max_baseload_period_years
    baseload_longterm_chart_timescales[:timescale_years]
  end

  def content(user_type: nil)
    charts_and_html = []
    charts_and_html.push( { type: :html,           content: "<h2>Electricity Baseload#{multiple_meters_total}</h2>" } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,           content: statement_of_baseload } )
    charts_and_html.push( { type: :html,           content: explanation_of_baseload } )
    charts_and_html.push( { type: :html,           content: benefit_of_moving_to_exemplar_baseload } )
    charts_and_html.push( { type: :chart,          content: baseload_one_year_chart } )
    charts_and_html.push( { type: :analytics_html, content: AdviceBase.highlighted_dummy_chart_name_html(baseload_one_year_chart[:config_name] ) } )
    charts_and_html.push( { type: :chart_name,     content: baseload_one_year_chart[:config_name] } )
    charts_and_html.push( { type: :html,           content: chart_drilldown_explanation } )
    charts_and_html += analysis_of_baseload(@school.aggregated_electricity_meters).flatten

    if max_baseload_period_years > 1.1
      charts_and_html.push( { type: :html,            content: "<h2>Electricity Baseload - Longer Term#{multiple_meters_total}</h2>" } )
      charts_and_html.push( { type: :html,            content: longterm_chart_intro } )
      charts_and_html.push( { type: :chart,           content: baseload_longterm_chart } )
      charts_and_html.push( { type: :analytics_html,  content: AdviceBase.highlighted_dummy_chart_name_html(baseload_longterm_chart[:config_name]) } )
      charts_and_html.push( { type: :chart_name,      content: baseload_longterm_chart[:config_name] } )
      charts_and_html.push( { type: :html,            content: longterm_chart_trend_should_be_downwards } )
    end

    charts_and_html += benchmark_exemplar_comparison

    # ap analysis_of_baseload(@school.aggregated_electricity_meters).flatten

    # charts_and_html += analysis_of_baseload(@school.aggregated_electricity_meters).flatten

    charts_and_html += baseload_charts_for_real_meters if @school.electricity_meters.length > 1

    charts_and_html += AdviceBaseloadCommentary.all_background_and_advice_on_reducing_issues

    remove_diagnostics_from_html(charts_and_html, user_type)
  end

  private

  def multiple_meters_total
    @school.electricity_meters.length > 1 ? ' (all meters)' : ''
  end

  def analysis_of_baseload(meter)
    commentary = AdviceBaseloadCommentary.new(@school, meter)
    commentary.all_commentary
  end

  def statement_of_baseload
    text = %{
      <p>
        Your electricity baseload over the last
        <%= baseload_one_year_chart_timescales[:timescale_description] %>
        was <%= format_kw(average_baseload_last_year_kw) %>.
        Other schools with a similar number of pupils have a baseload of <%= format_kw(benchmark_per_pupil_kw) %>.
      <p>
    }
    ERB.new(text).result(binding)
  end

  def explanation_of_baseload
    %{
      <p>
        Electricity baseload is the electricity needed to provide power to appliances
        that keep running at all times.
        It can be measured by looking at your school&apos;s out of hours electricity consumption.
      <p>
    }
  end

  def benefit_of_moving_to_exemplar_baseload
    text = %{
      <p>
        <% if one_year_saving_versus_benchmark_£_local > 0.0 %>
          Reducing a school&apos;s baseload is often the fastest way of reducing a school&apos;s
          energy costs and reducing its carbon footprint. If you matched the baseload
          of other schools of the same size you would save
          <%= format_£(one_year_saving_versus_benchmark_£_local) %> per year.
        <% else %>
          Your school&apos;s baseload is low, which is good and as a result you are saving
          <%= format_£(- 1.0 * one_year_saving_versus_benchmark_£_local) %> per year versus
          the average of other schools of a similar size.
        <% end %>

        <% if one_year_saving_versus_benchmark_£_local <= 0.0 && one_year_saving_versus_exemplar_£_local > 0.0 %>
          However, you could still improve by matching the baseload
          of the best performing schools saving
          <%= format_£(one_year_saving_versus_exemplar_£_local) %> per year.
        <% elsif one_year_saving_versus_exemplar_£_local > 0.0 %>
          If you matched the baseload of the best performing schools you could save
          <%= format_£(one_year_saving_versus_exemplar_£_local) %> per year.
        <% end %>
      </p>
    }
    ERB.new(text).result(binding)
  end

  def chart_drilldown_explanation
    %{
      <p>
        You can click on a day on the chart above and it will drilldown to
        show you the usage on that day.
      <p>
    }
  end

  def longterm_chart_intro
    %{
      <p>
        This chart shows you the same chart as above but for all the
        data we have available for you school - so you can see longer term
        trends in your baseload.
      <p>
    }
  end

  def longterm_chart_trend_should_be_downwards
    %{
      <p>
        You would expect baseload to reduce over
        time as appliances and computers have become more power efficient
        with lower standby power requirements.
        If this is not the case then
        you should look to identify the cause of the increase; you can
        use appliance monitors to determine the standby power of individual
        appliances - why not get the pupils to complete a survey?
      <p>
    }
  end

  def meter_name(meter)
    name = (meter.name.nil? || meter.name.empty?) ? '' : " #{meter.name}"
    stats = meter_breakdown_baseload_analysis[meter.mpan_mprn]
    avg = FormatEnergyUnit.format(:kw, stats[:kw], :html)
    pct = FormatEnergyUnit.format(:percent, stats[:percent], :html)
    pct_str = stats[:percent] == 1.0 ? '' : "#{pct},"
    annual_cost_£ = stats[:kw] * 24.0 * 365.0 * BenchmarkMetrics::ELECTRICITY_PRICE
    annual_cost_formatted = FormatEnergyUnit.format(:£, annual_cost_£, :html)
    "#{meter.mpxn.to_s + name} (#{avg} average, #{pct_str} #{annual_cost_formatted}/year)"
  end

  def sorted_meters_by_baseload
    meter_breakdown_baseload_analysis.sort_by { |mpan, v| -v[:percent] }.to_h
  end

  def meter_breakdown_baseload_analysis
    @meter_breakdown_baseload_analysis ||= calculate_percentage_baseload
  end

  def calculate_percentage_baseload
    total_baseload_kw = average_last_year_baseload_by_meter.values.map { |v| v[:kw] }.sum

    average_last_year_baseload_by_meter.transform_values do |kw|
      {
        kw:       kw[:kw],
        percent:  kw[:kw] / total_baseload_kw,
        meter:    kw[:meter]
      }
    end
  end

  def average_last_year_baseload_by_meter
    @average_last_year_baseload_by_meter ||= calculate_average_last_year_baseload_by_meter
  end

  def calculate_average_last_year_baseload_by_meter
    @school.electricity_meters.map do |meter|
      [
        meter.mpan_mprn,
        {
          kw: meter.amr_data.average_baseload_kw_date_range,
          meter: meter
        }
      ]
    end.to_h
  end

  def baseload_charts_for_real_meters
    sorted_meters_by_baseload.map do |mpan, info|
      [
        { type: :html, content: "<h2>Baseload for meter #{meter_name(info[:meter])}</h2>" },
        AdviceBase.meter_specific_chart_config(baseload_longterm_chart[:config_name], mpan),
        analysis_of_baseload(info[:meter]).flatten
      ]
    end.flatten
  end

  def benchmark_exemplar_comparison
    chart_name = baseload_benchmark_exemplar_chart[:config_name]
    [
      { type: :html,            content: "<h2>Comparison with benchmark and exemplar schools</h2>" },
      { type: :html,            content: intro_to_benchmark_exemplar_comparisons },
      { type: :analytics_html,  content: AdviceBase.highlighted_dummy_chart_name_html(chart_name) },
      { type: :chart_name,      content: chart_name },
      { type: :html,            content: addendum_to_benchmark_exemplar_comparisons }
    ]
  end

  def intro_to_benchmark_exemplar_comparisons
    AverageSchoolData.new.introduction_to_benchmark_and_exemplar_charts +
    AverageSchoolData.new.benchmark_and_exemplar_rankings(@school)
  end

  def addendum_to_benchmark_exemplar_comparisons
    AverageSchoolData.new.addendum_to_benchmark_and_exemplar_charts
  end
end
