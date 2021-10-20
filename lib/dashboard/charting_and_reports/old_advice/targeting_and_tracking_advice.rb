class TargetingAndTrackingAdvice < DashboardChartAdviceBase
  def generate_advice
    header_template = %{
      <%= HtmlTableFormattingWithHighlightedCells.cell_highlight_style %>
      <%= @body_start %>
      <p>
        Some ideas associated with tracking and tracing
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          This is the raw data for a school who have set a 5% reduction target at the start
          of the academic year.
        </p>
        <p>
          The data can either be presented on a monhtly individual basis or cumulatively.
          Cumulatively is more correct in that it accounts for good and bad months overall
          and is more tolerant for example of changes to Easter dates and how many weekends
          there are in a month. It is ultimately the target you are trying to track and not
          whether you are good one month versus another. Although a strategy of exceeding the
          target every month will work, it will also result on average in exceeding the target
          at the end of the year.
        </p>
        <p>
          The other nuance is the current partial month, the presentation see the last 2 tables
          below might be confusing. With this initial implementation the partial target is
          crudely apportioned, not taking into account weekends (or holidays). And, in the latter 2
          tables the months target is presented but the performance is versus the partial target
          which is not represented. The other choice is not to provide compariative data for the
          current month, however this doesn't provide an incentive for the school, and would only
          allow review at the end of each month.
        </p>
        <p>
          And finally, rounding to 2 signifcant figures will also probably cause confusion
          as the numbers don't necessily add up and the percents are not based on the presented
          values, but the raw internal kwh values?
        </p>

        <h2> Full table of data </h2>
        <p> <%= table.full_table_html %> </p>
        <h2> Simpler table with monthly targets </h2>
        <p> <%= table.simple_target_table_html %> </p>
        <h2> As above but cumulatively </h2>
        <p> <%= table.simple_culmulative_target_table_html %> </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  private

  def table
    @table ||= calculate_table
  end

  def calculate_table
    tbl = TargetingAndTrackingTable.new(@school, :electricity)
    tbl.analyse(nil)
    tbl
  end
end
