
require_relative './advice_general.rb'
class AdviceTargets < AdviceBase
  def initialize(school, fuel_type)
    super(school)
    @fuel_type = fuel_type
  end

  def enough_data
    aggregate_meter.enough_amr_data_to_set_target? ? :enough : :not_enough
  end

  def relevance
    (!aggregate_meter.nil? && aggregate_meter.target_set?) ? :relevant : :never_relevant
  end

  def content(user_type: nil)
    charts_and_html = []
    charts_and_html.push( { type: :html, content: "<h2>Setting and tracking targets for your #{@fuel_type.to_s.humanize}</h2>" } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,  content: brief_intro_to_targeting_and_tracking } )
    
    charts_and_html.push( { type: :html,  content: current_targets } )
    charts_and_html.push( { type: :html,  content: monthly_targeting_and_tracking_tables } )

    charts_and_html.push( { type: :html,  content: weekly_chart_intro } )
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_to_date_line)
    charts_and_html.push( { type: :html,  content: weekly_chart_drilldown} )
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_to_date_column)

    charts_and_html.push( { type: :html,  content: weekly_chart_intro_shorter_timescales } )
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_one_year_line)
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_one_year_column)


    charts_and_html.push( { type: :html,  content: culmulative_weekly_chart_intro } )
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_one_year_cumulative_line)
    create_chart(charts_and_html, :targeting_and_tracking_weekly_electricity_to_date_cumulative_line)

    charts_and_html.push( { type: :html,  content: introduction_to_targeting_and_tracking } )

    add_charts_for_testing(charts_and_html)

    remove_diagnostics_from_html(charts_and_html, user_type)
  end

  private

  def create_chart(charts_and_html, chart_name)
    charts_and_html.push( { type: :chart, content: run_chart(chart_name) } )
    charts_and_html.push( { type: :chart_name, content: chart_name } )
  end

  def current_targets
    text = %{
      <p>
        <% if single_target_set? %>
          Your school has a single target of a
          <%= FormatEnergyUnit.format(:percent, (1.0 - target_meter_attributes.target(last_meter_date)), :html) %>
          reduction set starting from
          <%= FormatEnergyUnit.format(:date, target_meter_attributes.first_target_date, :html) %>.
        <% else %>
          Your school has the following targets set
          <%= target_table_html %>
        <% end %>
      </p>
    }
    ERB.new(text).result(binding)
  end

  def target_meter_attributes
    @target_meter_attributes ||= TargetAttributes.new(aggregate_meter)
  end

  def single_target_set?
    target_meter_attributes.table.length == 1
  end

  def target_table_html
    relative_percents = target_meter_attributes.table.map { |row| [row[0].strftime('%d-%b-%Y'), row[1] - 1.0] }
    HtmlTableFormatting.new(['Start date','target'], relative_percents, nil, [String, :relative_percent]).html
  end

  def monthly_tracking_table
    @monthly_tracking_table ||= calculate_monthly_tracking_table
  end

  def calculate_monthly_tracking_table
    tbl = TargetingAndTrackingTable.new(@school, @fuel_type)
    tbl.analyse(nil)
    tbl
  end

  def monthly_targeting_and_tracking_tables
    text = %{
      <%= HtmlTableFormattingWithHighlightedCells.cell_highlight_style %>
      <p>
        This table shows you how the school has been doing on a monthly basis:
      </p>
      <p>
        <%=monthly_tracking_table.simple_target_table_html %>
      </p>
      <p>
        This table shows you the same information but cumulatively:
      </p>
      <p>
        <%=monthly_tracking_table.simple_culmulative_target_table_html %>
      </p>
      <% if monthly_tracking_table.cumulative_target_percent > 0.0 %>
        <p>
          Unfortunately you are currently running
          <%= monthly_tracking_table.year_to_date_percent_absolute_html %> above target.
        </p>
      <% else %>
        <p>
          Congratulations, you are currently running
          <%= monthly_tracking_table.year_to_date_percent_absolute_html %> below the target.
        </p>
      <% end  %>
      <p>
        So far you have spent
          <%= format_cell(:£, current_year_£) %> (<%= format_cell(:kwh, current_year_kwh) %>)
        versus your target of
          <%= format_cell(:£, current_year_target_£_to_date) %> (<%= format_cell(:kwh, current_year_target_kwh_to_date) %>).
      </p>
    }
    ERB.new(text).result(binding)
  end

  def culmulative_weekly_chart_intro
    text = %{
      <p>
        The chart below shows how you are progressing on a cumulative basis
        versus the targets you have set:
      </p>
    }
    ERB.new(text).result(binding)
  end

  def weekly_chart_intro
    text = %{
      <p>
        The chart below shows how you are progressing on a weekly basis
        versus the targets you have set:
      </p>
    }
    ERB.new(text).result(binding)
  end

  def weekly_chart_intro_shorter_timescales
    text = %{
      <p>
        The chart below shows how you have progressed to date on a weekly basis
        versus the targets you have set:
      </p>
    }
    ERB.new(text).result(binding)
  end

  def weekly_chart_drilldown
    text = %{
      <p>
        If you want to see more detail you can drilldown by clicking on points
        on the chart.
      </p>
    }
    ERB.new(text).result(binding)
  end

  def format_cell(datatype, value)
    FormatEnergyUnit.format(datatype, value, :html, false, false, :target) 
  end

  def fuel_type_html
    @fuel_type.to_s.humanize
  end

  def last_meter_date
    aggregate_meter.amr_data.end_date
  end

  def brief_intro_to_targeting_and_tracking
    text = %{
      <p>
        'Targeting and Tracking' on Energy Sparks lets you set separate targets for reducing
        your electricity, gas or storage heater consumption over the next year. Energy Sparks
        then lets you track how you are progressing versus these targets throughout the year.
      </p>
      <p>
        Targets are set as a percentage of last year's energy consumption using the targetting setting
        editor on the 'Manage School' menu above. So for example by setting a 95% target you would be
        aiming to reduce your <%= @fuel_type.to_s %> consumption by 5% compared with last year.
      </p>
    }
    ERB.new(text).result(binding)
  end

  def introduction_to_targeting_and_tracking
    text = %{
      <h2>Introduction to Targeting and Tracking</h2>
      <p>
        'Targeting and Tracking' on Energy Sparks lets you set separate targets for reducing
        your electricity, gas or storage heater consumption over the next year.
        You can do this by selecting the 'Edit targets' option on the 'Manage School'
        menu above.
      </p>
      <p>
        Targets are set as a percentage of last year's energy consumption. If for example
        you set a target -5&percnt; reduction, and you consumed 100,000kWh of electricity
        last year, then your target for this year would be 95,000kWh. Targets can be changed
        at any time and can vary for different time periods. They apply continuously,
        so if your target was -5&percnt; this year, and you achieved this goal, in the
        case of the example 95,000kWh then if you left the target unchanged then next year's
        target would be 90,250kWh.
      </p>
      <p>
        If this is the first time you are setting a target and
        it is already part way through the year, the target is tracked on a pro-rata basis
        through the remainder of the year. So, setting a 5&percnt; target half-way through
        the academic year would imply approximately a 2.5&percnt; target for the year as a whole.
      </p>
      <p>
        When setting a target review the some of the 'Energy saving opportunities' on the Management
        dashboard and think how much you might be able to achieve by for example turning the heating
        off in all holidays compared with the holidays you left it on last year? Don't try to be too
        ambitious, achieving a realistic 5% target this year is much better than failing to meet
        a more ambitious target this year and getting disillusioned. Reducing your costs and carbon
        emissions is a long-term process and needs careful thought and planning. 
      </p>
      <p>
        You can adjust the targets throughout the year and their adjustment works retrospectively.
        However, we don't encourage you to do this if part way through the year you are failing
        to meet your original target; try to persist at meeting your target.
      </p>
      <p>
        Energy Sparks compares your current consumption and targets versus an average consumption
        from a similar time last year, matching up school days, weekends, and holidays.
      </p>
      <p>
        In addition to the tables and charts on this page which help you understand how you are doing
        versus your targets, Energy Sparks will send weekly emails or text alerts to your school telling
        you whether you are on track to meet the targets, for the year to date, over the last 4 weeks, and
        for the most recent week.
      </p>
    }
    ERB.new(text).result(binding)
  end
end

class AdviceTargetsElectricity < AdviceTargets
  def initialize(school)
    super(school, :electricity)
  end
  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
  def monthly_chart
    :targeting_and_tracking_weekly_electricity_1_year_line
  end
  def monthly_chart_cumulative
    :targeting_and_tracking_weekly_electricity_1_year_cumulative_line
  end
  def add_charts_for_testing(charts_and_html)
    %i[
    ].each do |chart_name|
      create_chart(charts_and_html, chart_name)
    end
  end
end

class AdviceTargetsGas < AdviceTargets
  def initialize(school)
    super(school, :gas)
  end
  protected def aggregate_meter
    @school.aggregated_heat_meters
  end
  def monthly_chart
    :targeting_and_tracking_weekly_gas_1_year_line
  end
  def monthly_chart_cumulative
    :targeting_and_tracking_weekly_electricity_1_year_cumulative_line
  end
  def add_charts_for_testing(charts_and_html)
    %i[
    ].each do |chart_name|
      create_chart(charts_and_html, chart_name)
    end
  end
  def add_charts_for_testing(charts_and_html)
  end
end

class AdviceTargetsStorageHeaters < AdviceTargets
  def initialize(school)
    super(school, :storage_heaters)
  end
  protected def aggregate_meter
    @school.storage_heater_meter
  end
  def add_charts_for_testing(charts_and_html)
  end
end
