
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

  def baseload_longterm_chart_timescales
    self.class.chart_timescale_and_dates(baseload_longterm_chart)
  end

  def max_baseload_period_years
    baseload_longterm_chart_timescales[:timescale_years]
  end

  def content(user_type: nil)
    charts_and_html = []
    charts_and_html.push( { type: :html, content: '<h2>Electricity Baseload</h2>' } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,  content: statement_of_baseload } )
    charts_and_html.push( { type: :html,  content: explanation_of_baseload } )
    charts_and_html.push( { type: :html,  content: benefit_of_moving_to_exemplar_baseload } )
    charts_and_html.push( { type: :chart, content: baseload_one_year_chart } )
    charts_and_html.push( { type: :chart_name, content: baseload_one_year_chart[:config_name] } )
    charts_and_html.push( { type: :html,  content: chart_seasonal_trend_comment } ) if max_baseload_period_years > 0.75
    charts_and_html.push( { type: :html,  content: chart_drilldown_explanation } )

    if max_baseload_period_years > 1.1
      charts_and_html.push( { type: :html,  content: '<h2>Electricity Baseload - Longer Term</h2>' } )
      charts_and_html.push( { type: :html,  content: longterm_chart_intro } )
      charts_and_html.push( { type: :chart, content: baseload_longterm_chart } )
      charts_and_html.push( { type: :chart_name, content: baseload_longterm_chart[:config_name] } )
      charts_and_html.push( { type: :html,  content: longterm_chart_trend_should_be_downwards } )
    end
    charts_and_html
  end

  private

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
        Reducing a school&apos;s baseload is often the fastest way of reducing a school&apos;s
        energy costs and reducing its carbon footprint. If you matched the baseload
        of other schools of the same size you would save
        <%= format_£(one_year_saving_versus_benchmark_£) %>.
        If you matched the baseload of the best performing schools you could save
        <%= format_£(one_year_saving_versus_exemplar_£) %>.
      <p>
    }
    ERB.new(text).result(binding)
  end

  def chart_seasonal_trend_comment
    %{
      <p>
        Ideally the baseload should stay the same throughout the year and
        not increase in winter (a heating problem) or the summer (air conditioning).
      <p>
    }
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
        This chart shows you the same chart as above but for all the meter
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
end