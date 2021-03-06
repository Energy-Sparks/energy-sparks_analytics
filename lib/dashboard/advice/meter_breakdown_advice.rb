class AdviceMeterBreakdownBase < AdviceBase
  def enough_data
    :enough 
  end

  def relevance
    aggregate_meter.nil? || underlying_meters.length <= 1 || aggregate_meter.amr_data.days < 14 ? :never_relevant : :relevant
  end

  def self.template_variables
    { 'Summary' => { summary: { description: 'Breakdown of meter data', units: String } } }
  end

  def summary
    @summary ||= summary_text
  end

  def summary_text
    'A breakdown to individual meters'
  end

  def breakdown_chart
    @bdown_chart ||= charts[0]
  end

  def content(user_type: nil)
    charts_and_html = []
    charts_and_html.push( { type: :html, content: '<h2>Breakdown of underlying meters</h2>' } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,       content: introduction } )
    charts_and_html.push( { type: :html,       content: chart_intro } )
    charts_and_html.push( { type: :chart,      content: breakdown_chart } )
    charts_and_html.push( { type: :chart_name, content: breakdown_chart[:config_name] } )
    charts_and_html.push( { type: :html,       content: table_timescale_html } )
    charts_and_html.push( { type: :html,       content: table_breakdown_html } )
    charts_and_html.push( { type: :html,       content: table_comments } )
    remove_diagnostics_from_html(charts_and_html, user_type)
  end

  def rating
    5.0
  end

  private

  def introduction
    text = %{
      <p>
        Your school has multiple <%= aggregate_meter.fuel_type.to_s %> underlying meters.
      <p>
    }
    ERB.new(text).result(binding)
  end

  def chart_intro
    %{
      <p>
        The chart below provides a weekly breakdown of the energy used by
        each underlying meter. Clicking on the chart columns allows you to
        drilldown to more detailed data, clicking on the legend allows you to
        add and remove meters.
      <p>
    }
  end

  def table_timescale_html
    timescale = self.class.chart_timescale_and_dates(breakdown_chart)
    text = %{
      <p>
        This table covers the most recent <%= timescale[:timescale_description] %>
        from <%= timescale[:start_date] %> to <%= timescale[:end_date] %>:
      </p>
    }
    ERB.new(text).result(binding)
  end

  def table_breakdown_html
    kwh_per_meter = breakdown_chart[:x_data].map { |meter_name, kwhs| [meter_name, kwhs.sum] }.to_h
    total = kwh_per_meter.values.sum
    rows = kwh_per_meter.map { |meter_name, kwh| [meter_name, kwh, kwh / total ] }
    rows.sort! { |a, b| (a[2] + b[2]).nan? ? a[1] <=> b[1] : a[2] <=> b[2]}
    total_row = ['Total', total, 1.0]
    header = ['Meter Name', 'Kwh', 'Percent']
    row_units = [String, :kwh, :percent]
    html_table = HtmlTableFormatting.new(header, rows, total_row, row_units)
    '<p> ' + html_table.html + ' </p>'
  end

  def table_comments
    text = %{
      <p>
        Having multiple meters can help you understand your energy use better,
        however, there is a significant standing charge for each meter of more than 
        &pound; 1,000 per year, so there is potential for saving by consolidating meters.
      <p>
    }
    ERB.new(text).result(binding)
  end
end
