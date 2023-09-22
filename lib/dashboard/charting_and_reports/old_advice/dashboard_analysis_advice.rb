# generates advice for the dashboard in a mix of text, html and charts
# primarily bound up with specific charts, indexed by the symbol which represents
# the chart in chart_manager.rb e.g. :benchmark
# generates advice with different levels of expertise
require 'html-table'
require 'erb'

class DashboardChartAdviceBase
  include Logging

  attr_reader :header_advice, :footer_advice, :body_start, :body_end
  def initialize(school, chart_definition, chart_data, chart_symbol)
    @school = school
    @chart_definition = chart_definition
    @chart_data = chart_data
    @chart_symbol = chart_symbol
    @header_advice = nil
    @footer_advice = nil
=begin
    @add_extra_markup = ENV['School Dashboard Advice'] == 'Include Header and Body'
    if @add_extra_markup
      @body_start = '<html><head>'
      @body_end = '</head></html>'
    else
=end
      @body_start = ''
      @body_end = ''
=begin
    end
=end

  end

  def self.advice_factory_group(chart_type, school, chart_definition, charts)
    case chart_type
    when :simulator_group_by_week_comparison
      SimulatorByWeekComparisonAdvice.new(school, chart_definition, charts, chart_type)
    when :simulator_group_by_day_of_week_comparison
      SimulatorByDayOfWeekComparisonAdvice.new(school, chart_definition, charts, chart_type)
    when :simulator_group_by_time_of_day_comparison
      SimulatorByTimeOfDayComparisonAdvice.new(school, chart_definition, charts, chart_type)
    end
  end

  def self.advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :frost, :frost_1,  :frost_2,  :frost_3
      HeatingFrostAdviceAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when :electricity_simulator_pie
      ElectricitySimulatorBreakdownAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_simulator_pie_detail_page
      ElectricitySimulatorDetailBreakdownAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_electricity_actual_for_simulator_comparison
      SimulatorByWeekActual.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_electricity_simulator
      SimulatorByWeekSimulator.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_by_day_of_week_simulator
      SimulatorByDayOfWeekActual.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_by_day_of_week_actual_for_simulator_comparison
      SimulatorByDayOfWeekSimulator.new(school, chart_definition, chart_data, chart_symbol)
    when :intraday_electricity_simulator_actual_for_comparison
      SimulatorByTimeOfDayActual.new(school, chart_definition, chart_data, chart_symbol)
    when :intraday_electricity_simulator_simulator_for_comparison
      SimulatorByTimeOfDaySimulator.new(school, chart_definition, chart_data, chart_symbol)
    when  :group_by_week_electricity_simulator_lighting,
          :intraday_electricity_simulator_lighting_kwh,
          :intraday_electricity_simulator_lighting_kw
          SimulatorLightingAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_simulator_ict,
          :electricity_by_day_of_week_simulator_ict,
          :intraday_electricity_simulator_ict
          SimulatorICTAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_simulator_electrical_heating
          SimulatorElectricalHeatingAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_simulator_security_lighting
          :intraday_electricity_simulator_security_lighting_kwh
          SimulatorSecurityLightingAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_air_conditioning,
          :intraday_electricity_simulator_air_conditioning_kwh
          SimulatorAirConAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_flood_lighting,
          :intraday_electricity_simulator_flood_lighting_kwh
          SimulatorFloodLightingAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_kitchen,
          :intraday_electricity_simulator_kitchen_kwh
          SimulatorKitchenAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_simulator_boiler_pump,
          :intraday_electricity_simulator_boiler_pump_kwh
          SimulatorBoilerPumpAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :group_by_week_electricity_simulator_solar_pv,
          :intraday_electricity_simulator_solar_pv_kwh
          SimulatorSolarAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when  :intraday_line_school_days_6months_simulator,
          :intraday_line_school_days_6months_simulator_submeters
          SimulatorMiscOtherAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    else
      res = DashboardEnergyAdvice.heating_model_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
      res
    end
  end

  def generate_advice
    raise EnergySparksUnexpectedStateException.new('Error: unexpected call to DashboardChartAdviceBase abstract base class')
  end

  protected

  def calculate_alert(alert_class, fuel_type, asof_date = nil)
    aggregate_meter = @school.aggregate_meter(fuel_type)
    return nil if aggregate_meter.nil?
    alert = alert_class.new(@school)
    alert.analyse(asof_date || aggregate_meter.amr_data.end_date)
    alert
  rescue => e
    # PH in 2 minds whether this general catch all should reraise or not?
    logger.info "Failed to calculate alert #{alert_class.class.name}: #{e.message}"
    nil
  end

  # copied from heating_regression_model_fitter.rb TODO(PH,17Feb2019) - merge
  def html_table(header, rows, totals_row = nil)
    HtmlTableFormatting.new(header, rows, totals_row).html
  end

  def generate_html(template, binding)
    begin
      rhtml = ERB.new(template)
      rhtml.result(binding)
      # rhtml.gsub('£', '&pound;')
    rescue StandardError => e
      logger.error "Error generating html for #{self.class.name}"
      logger.error e.message
      logger.error e.backtrace
      puts e.message
      puts e.backtrace
      '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
    end
  end

  def generate_html_from_array_adding_body_tags(html_components, binding)
    template = [
      '<%= @body_start %>',
      html_components,
      '<%= @body_end %>'
    ].flatten.join(' ').gsub(/^  /, '')

    generate_html(template, binding)
  end

  def nil_advice
    footer_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    generate_html(footer_template, binding)
  end

  def link(url, text_before, click_text, text_after)
    "#{text_before}<a href=\"#{url}\" target=\"_blank\">#{click_text}</a>#{text_after}"
  end

  def sim_link(bookmark, text_before = 'For further information ', click_text = 'click here', text_after = '.')
    link('https://blog.energysparks.uk/electricity-simulator/' + bookmark, text_before, click_text, text_after)
  end

  def equivalence_tool_tip_html(equivalence_text, calculation_text)
    "#{equivalence_text} <button class=\"btn btn-secondary\" data-toggle=\"popover\" data-container=\"body\" data-placement=\"top\" data-title=\"How we calculate this\" data-content=\"#{calculation_text}\"> See how we calculate this</button>"
  end

  def random_equivalence_text(kwh, fuel_type, uk_grid_carbon_intensity = EnergyEquivalences::UK_ELECTRIC_GRID_CO2_KG_KWH)
    equiv_type, conversion_type = EnergyEquivalences.random_equivalence_type_and_via_type(uk_grid_carbon_intensity)
    _val, equivalence, calc, in_text, out_text = EnergyEquivalences.convert(kwh, :kwh, fuel_type, equiv_type, equiv_type, conversion_type, EnergyEquivalences::UK_ELECTRIC_GRID_CO2_KG_KWH)
    equivalence_tool_tip_html(equivalence, in_text + out_text + calc)
  end

  def percent(value)
    (value * 100.0).round(0).to_s + '%'
  end

  def kwh_to_pounds_and_kwh(kwh, fuel_type_sym, data_units = @chart_definition[:yaxis_units], £_datatype = :£)
    pounds = YAxisScaling.new.scale(data_units, £_datatype, kwh, fuel_type, @school)
    '&pound;' + FormatEnergyUnit.scale_num(pounds) + ' (' + FormatEnergyUnit.scale_num(kwh) + 'kWh)'
  end

  def benchmark_data_deprecated(fuel_type, benchmark_type, datatype)
    @alerts ||= {}
    @alerts[fuel_type] ||= AlertAnalysisBase.benchmark_alert(@school, fuel_type, last_chart_end_date)
    @alerts[fuel_type].benchmark_chart_data[benchmark_type][datatype]
  end

  def benchmark_alert(fuel_type)
    @benchmark_alerts ||= {}
    @benchmark_alerts[fuel_type] ||= AlertAnalysisBase.benchmark_alert(@school, fuel_type, last_chart_end_date)
  end

  def benchmark_data(fuel_type, benchmark_type, datatype, saving = false)
    if saving
      benchmark_alert(fuel_type).benchmark_chart_data[benchmark_type][:saving][datatype]
    else
      benchmark_alert(fuel_type).benchmark_chart_data[benchmark_type][datatype]
    end
  end

  def out_of_hours_alert(fuel_type)
    @out_of_hours_alerts ||= {}
    @out_of_hours_alerts[fuel_type] ||= AlertAnalysisBase.out_of_hours_alert(@school, fuel_type, last_chart_end_date)
  end

  def meter_tariffs_have_changed?(fuel_type, start_date = nil, end_date = nil)
    start_date ||= @school.aggregate_meter(fuel_type).amr_data.start_date
    end_date   ||= @school.aggregate_meter(fuel_type).amr_data.end_date
    @school.aggregate_meter(fuel_type).meter_tariffs.meter_tariffs_differ_within_date_range?(start_date, end_date)
  end

  def switch_to_kwh_chart_if_economic_tariffs_changed(fuel_type, start_date = nil, end_date = nil)
    if meter_tariffs_have_changed?(fuel_type, start_date, end_date)
      txt = %(
        Your tariff has changed over the period of the chart above and other charts on this page.
        Make sure the y-axis is set to kWh by selecting &apos;Change Unit&apos; to kWh so you
        can see how your <%= fuel_type.to_s %> consumption has changed over time without the
        impact of the tariff change.
      )
      ERB.new(txt).result(binding)
    else
      %()
    end
  end

  def switch_to_kwh_chart_if_economic_tariffs_changed_in_last_2_weeks(fuel_type)
    end_date = @school.aggregate_meter(fuel_type).amr_data.end_date
    start_date = [end_date - 7 - 6, @school.aggregate_meter(fuel_type).amr_data.start_date].max

    if meter_tariffs_have_changed?(fuel_type, start_date, end_date)
      txt = %(
        Your <%= fuel_type.to_s %> tariff has changed in the last 2 weeks.
        Make sure the y-axis is set to kWh by selecting &apos;Change Unit&apos; to kWh so you
        can see how your <%= fuel_type.to_s %> consumption has changed over the
        last 2 weeks without the impact of the tariff change.
      )
      ERB.new(txt).result(binding)
    else
      %()
    end
  end

  def annual_£current_cost_of_1_kw_html
    FormatEnergyUnit.format(:£current, annual_£current_cost_of_1_kw, :html)
  end

  def annual_£current_cost_of_1_kw
    blended_rate_£current_per_kwh * 24.0 * 365.0
  end

  def blended_rate_£current_per_kwh_html
    FormatEnergyUnit.format(:£_per_kwh, blended_rate_£current_per_kwh, :html)
  end

  def blended_rate_£current_per_kwh
    @school.aggregated_electricity_meters.amr_data.current_tariff_rate_£_per_kwh
  end

  def annualx5_£current_cost_of_1_kw_html
    FormatEnergyUnit.format(:£current, 5.0 * annual_£current_cost_of_1_kw, :html)
  end

  def last_chart_end_date
    @chart_data[:x_axis_ranges].flatten.sort.last
  end

  def html_table_from_graph_data(data, fuel_type = :electricity, totals_row = true, column1_description = '', sort = 0)
    total = 0.0

    if sort == 0
      sorted_data = data
    elsif sort > 0
      sorted_data = data.sort_by {|_key, value| value[0]}
    else
      sorted_data = data.sort_by {|_key, value| value[0]}
      sorted_data = sorted_data.reverse
    end

    units = @chart_definition[:yaxis_units]

    data.each_value do |value|
      total += value[0]
    end

    template = %{
      <table class="table table-striped table-sm">
        <thead>
          <tr class="thead-dark">
            <th scope="col"> <%= column1_description %> </th>
            <th scope="col" class="text-center">kWh &#47; year </th>
            <th scope="col" class="text-center">&pound; &#47;year </th>
            <th scope="col" class="text-center">CO2 kg &#47;year </th>
            <th scope="col" class="text-center">Percent </th>
          </tr>
        </thead>
        <tbody>
          <% sorted_data.each do |row, value| %>
            <tr>
              <td><%= row %></td>
              <% val = value[0] %>
              <% pct = val / total %>
              <td class="text-right"><%= YAxisScaling.convert(units, :kwh, fuel_type, val, @school) %></td>
              <% if row.match?(/export/i) %>
                <td class="text-right"><%= YAxisScaling.convert(units, :£, :solar_export, val, @school) %></td>
              <% else %>
                <td class="text-right"><%= YAxisScaling.convert(units, :£, fuel_type, val, @school) %></td>
              <% end %>
              <td class="text-right"><%= YAxisScaling.convert(units, :co2, fuel_type, val, @school) %></td>
              <td class="text-right"><%= percent(pct) %></td>
            </tr>
          <% end %>

          <% if totals_row %>
            <tr class="table-success">
              <td><b>Total</b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :kwh, fuel_type, total, @school) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :£, fuel_type, total, @school) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :co2, fuel_type, total, @school) %></b></td>
              <td></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end
end

#==============================================================================
#Frost page chart
class HeatingFrostAdviceAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :frost || @chart_type == :frost_1 %>
        <p>
        'Frost Protection' is a feature built into most school boiler controllers
        which turns the heating on when it is cold outside in order to prevent
        frost damage to hot and cold water pipework.
        </p>
        <p>
        A well programmed control will turn the boiler on if a number of conditions are met, typically:
        </p>
        <ul>
          <li>The outside temperature is below 4C (the point at which water starts to freeze and expand)</li>
          <li>And, the internal temperature is below 8C</li>
          <li>And, for some controllers if the temperature of the water in the central heating system is below 2C</li>
        </ul>
        <p>
        Typically, this means the 'frost protection' only turns the heating on if it is cold outside, AND
        the heating has been off for at least 24 hours - as it normally takes this long for a school to
        cool down and the internal temperature of the school to drop below 8C. So, in general in very cold weather
        the heating would probably not come on a Saturday, but on a Sunday when the school has cooled down
        sufficiently.
        </p>
        <p>
        Although 'frost protection' uses energy and therefore it costs money to run, it is cheaper than
        the damage which might be caused from burst pipes. Some schools don't have frost protection
        configured for their boilers, and although this saves money for most of the year, it is common
        for these schools to leave their heating on during winter holidays, which is significantly more expensive
        than if frost protection is allowed to provide the protection automatically.
        </p>
      <% end %>
      <% if @chart_type == :frost_1 %>
        <p>
        The 3 graphs below which are for the coldest weekends of recent years, attempt to demonstrate whether
        </p>
        <ol type="a">
        <li>Frost protection is configured for your school and</li>
        <li>whether it is configured correctly and running efficiently</li>
        </ol>
      <% end %>
      <% if @chart_type == :frost %>
      <p>
        The graph below which is for the coldest weekend of recent years, attempts to demonstrate whether
        </p>
        <ol type="a">
        <li>Frost protection is configured for your school and</li>
        <li>whether it is configured correctly and running efficiently</li>
        </ol>
        <p>You can check another frosty weekend by clicking the move forward/back frosty day buttons</p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :frost || @chart_type == :frost_1 %>
      <p>
        The graph shows both the gas consumption (blue bars), and the outside temperature
        (dark blue line) on a cold weekend (Saturday through to Monday).
        If frost protection is working the heating (gas consumption) should come on when
        the temperature drops below 4C - but not immediately on the Saturday as the
        'thermal mass' of the building will mean the internal temperature stays above 8C
        for at least 24 hours after the school closed on a Friday.
      </p>
      <p>
        If the outside temperature rises above 4C, the heating should go off. The amount
        of gas consumption (blue bars) should be about half the consumption of a school
        day (e.g. the Monday), as the heating requirement is roughly proportional
        to the difference between the inside and outside temperatures, and because
        the school is only being heated to 8C rather than the 20C of a school
        day then much less energy will be used.
      </p>
      <p>
      Can you see any of these characteristics in the graph above, or the two other example
      graphs for your school below?
      </p>
      <% end %>
      <% if @chart_type == :frost || @chart_type == :frost_3 %>
        <p>
        The graphs can be difficult to interpret sometimes, so if you are uncertain about what
        you are seeing please <a href="mailto:hello@energysparks.uk?subject=Boiler Frost Protection&">contact us</a>
        and we will look for you, and let you know what we think.
        </p>
        <p>
        A working frost protection system can save a school money:
        </p>
        <ul>
          <li>Without frost protection, a school either risks pipework damage, or
              is forced to leave their heating on at maximum power over cold weeks and holidays</li>
          <li>Sometimes, frost protection is mis-configured, so comes on when the temperature is above 4C outside,
          or is configured to come on and bring the school up to too high a temperature e.g. 20C.</li>
        </ul>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class ElectricitySimulatorBreakdownAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice

    table_info = html_table_from_graph_data(@chart_data[:x_data], :electricity, true, 'Appliance Type', -1)

    header_template = %{
      <%= @body_start %>
        <% if @add_extra_markup %>
        <h1>Electricity Simulator Results</h1>
        <% end %>
        <p>
        The Energy Sparks Electricity Simulator breaks down the electricity use within a school to different appliance types.
        Initially, it does this automatically based on the existing smart meter data, and a knowledge of the consumption
        of appliances at other schools where we have undertaken a physical audit of appliances in the past.
        As such it is an 'educated guess' at how electricity is consumed in a school and can be refined by an audit of a school's
        appliances which could be performed by pupils.
        </p>
        <p>
        The simulator is designed to help make more rational decisions when replacing appliances,
        for example it allows via the configuration editor you to answer the question
        'How much would I save if I installed more energy efficient lighting?',
        or 'How much would I save if I replaced the school's ICT servers with more efficient ones?
        </p>
        <p>
        For each appliance type, using a variety of external data (e.g. temperature, sunshine data and solar PV data)
        and occupancy patterns it assesses realistic usages for every &frac12; hour for each appliance type.
        The results are presented below.
        </p>
        <p>
        The data presented is for the current year to date:
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <%= table_info %>
      </p>
      <p>
        If you are using the simulator to make a decision about an investment in more efficient equipment, you
        should multiply the annual savings by the life of the investment typically 5 to 15 years.
      </p>
      <p> <%= sim_link('') %> </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class ElectricitySimulatorDetailBreakdownAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice

    table_info = html_table_from_graph_data(@chart_data[:x_data], :electricity, true, 'Appliance Type', -1)

    header_template = %{
      <%= @body_start %>
        <% if @add_extra_markup %>
          <h1>Electricity Simulator Results Detailed Breakdown</h1>
        <% end %>
        <p>
          The Energy Sparks Electricity Simulator breaks down the electricity use within a school to different appliance types.
          Initially, it does this automatically based on the existing smart meter data, and a knowledge of the consumption
          of appliances at other schools where we have undertaken a physical audit of appliances in the past.
          As such it is an 'educated guess' at how electricity is consumed in a school
          and can be refined by an audit of a school's appliances which could be performed by pupils.
        </p>
        <p>
          The simulator is designed to help make more rational decisions when replacing appliances, for example it allows
          via the configuration editor you to answer the question 'How much would I save if I installed more energy efficient lighting?', or
          'How much would I save if I replaced the school's ICT servers with more efficient ones?
        </p>
        <p>
          For each appliance type, using a variety of external data (e.g. temperature, sunshine data and solar PV data) and
          occupancy patterns it assesses realistic usages for every &frac12; hour
          for each appliance type. The results are presented below.
        </p>
        <p>
          The data presented is for the current year to date:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <%= table_info %>
      <p>
      <p>
        If you are using the simulator to make a decision about an investment in more efficient equipment, you
        should multiply the annual savings by the life of the investment typically 5 to 15 years.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class SimulatorByWeekComparisonAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, charts, chart_symbol)
    super(school, chart_definition, charts, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <% if @add_extra_markup %>
          <h1>Comparison of Weekly Electricity Consumption (Actual versus Simulator)</h1>
        <% end %>
        <p>
          The two graphs below show the real electricity consumption from the school's electricity smart meter(s)
          versus the consumption predicted by Energy Spark's Electricity Simulator.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        Please compare the 2 charts above.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class SimulatorByDayOfWeekComparisonAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, charts, chart_symbol)
    super(school, chart_definition, charts, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <% if @add_extra_markup %>
          <h1>Comparison of Day of the Week Electricity Consumption (Actual versus Simulator)</h1>
        <% end %>
        <p>
          The two graphs below show the real electricity consumption from the school's electricity smart meter(s)
          versus the consumption predicted by Energy Spark's Electricity Simulator for the last year
          broken down by the day of the week.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        Please compare the 2 charts above.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorByTimeOfDayComparisonAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, charts, chart_symbol)
    super(school, chart_definition, charts, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <% if @add_extra_markup %>
          <h1>Comparison of Time of Day Electricity Consumption (Actual versus Simulator)</h1>
        <% end %>
        <p>
          The two graphs below show the real electricity consumption from the school's electricity smart meter(s)
          versus the consumption predicted by Energy Spark's Electricity Simulator for the last year
          broken down by the time of day.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        Please compare the 2 charts above.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorByWeekActual < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the real smart meter data from your school grouped on a weekly basis over the last year.
        You should compare it with the graph to the left which is the simulated smart meter data.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorByWeekSimulator < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the simulated smart meter data from your school grouped on a weekly basis over the last year.
        You should compare it with the graph to the right which is calculated actual smart meter data.
        Ideally, both graphs should look very similar; the simulator configuration
        should be used to make them converge and look the same in terms of (seasonal) usage throughout the year.
        </p>
        <p>
        So matching winter with winter usage and summer with summer usage by changing the simulator configuration
        information for different types of appliances should help line up these two graphs. Lighting and electrical
        heating typically have the biggest impact on seasonal differences.
        </p>
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class SimulatorByDayOfWeekActual < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the real smart meter data from your school grouped day of the week over the last year.
        You should compare it with the graph to the left which is the simulated smart meter data.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorByDayOfWeekSimulator < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the simulated smart meter data from your school grouped by day of the week over the last year.
        You should compare it with the graph to the right which is calculated actual smart meter data.
        Ideally, both graphs should look very similar; the simulator configuration
        should be used to make them converge and look the same in terms of usage on each day of the week.
      </p>
      <p>
        So matching the actual usage and the simulated usage involves changing configuration of items which either
        dominate the weekend usage (baseload - ICT Servers, Security Lights) versus weekday usage (Lighting etc.)
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class SimulatorByTimeOfDayActual < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the real smart meter data from your school grouped time of day over the last year.
        You should compare it with the graph to the left which is the simulated smart meter data.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorByTimeOfDaySimulator < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The graph above is the simulated smart meter data from your school grouped by time of day over the last year.
        You should compare it with the graph to the right which is calculated actual smart meter data.
        Ideally, both graphs should look very similar; the simulator configuration
        should be used to make them converge and look the same in terms of usage by time of day.
      </p>
      <p>
        This is quite similar to the charts on the simulator configuration editor pages but covers usage
        across the whole of the year.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class SimulatorApplianceAdviceBase < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <h2>Advice for chart <%= @chart_type %> using <%= self.class.name %></h2>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        Please look at the chart above.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorLightingAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_simulator_lighting
  # intraday_electricity_simulator_lighting_kwh
  # intraday_electricity_simulator_lighting_kw
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_simulator_lighting %>
        <% if @add_extra_markup %>
          <h2>Simulator Lighting Charts:</h2>
        <% end %>
        <p>
        The 3 charts below show the electricity consumption predicted by the simulator for internal lighting in the school.
        Most of this lighting is likely to be in classrooms.
        </p>
        <p>
        The first chart groups the lighting usage by week across the whole year.
        Can you think why lighting usage might vary by season of the year?
        </p>
      <% end %>
      <% if @chart_type == :intraday_electricity_simulator_lighting_kwh %>
        <p>
        The next two charts show the usage by time of day. The first shows the
        energy use across the year by time of day.
        </p>
        <p>
        Does this look about right for your school? Does the lighting usage gradually increase
        when the first person arrives at the school in the morning, then decrease as people
        leave the school in the evening? If you think the lighting pattern doesn't
        look right for your school you can change it in the configuration, but please
        check that the side by side comparison charts broken down by time of day
        on the main simulator results page still look similar if you change the configuration?
        </p>
      <% end %>
      <% if @chart_type == :intraday_electricity_simulator_lighting_kw %>
        <p>
        The final lighting chart shows the average power consumption by time of day across the year.
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_lighting_kw %>
      <p>
        Look at the three charts above, do you think they represent the lighting usage in your school?
      </p>
      <p>
        What happens if you upgrade the school's lighting to more efficient lighting?
      </p>
      <p>
        You can see the impact by going to the simulator lighting configuration and
        changing the lumens/watt setting. Lumens is a measure of lighting output, watts
        is a measure of electrical power. The higher the lumens/watt the more efficient
        lighting is. This can range from 10 lumens/watt for old fashioned incandescent
        lighting to modern LED lighting at 110 lumens/watt. Most schools have florescent
        lighting, older T8 (1" diameter tubes (the 8 is the number of eighths on an inch)) lighting
        is 40 to 50 lumens/watt, more modern T5 florescent tubes are 90 lumens/watt.
      </p>
      <p> <%= sim_link('#lighting') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorICTAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_simulator_ict
  # electricity_by_day_of_week_simulator_ict
  # intraday_electricity_simulator_ict
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_simulator_ict %>
        <% if @add_extra_markup %>
          <h2>Simulator ICT (Servers, Desktops, Laptops) Charts:</h2>
        <% end %>
        <p>
        The 3 charts below show the electricity consumption predicted by the simulator for ICT in the school.
        </p>
        <p>
        ICT (Servers, Desktops, Laptops, Network hardware) is used throughout most schools and
        is often the largest or the second largest consumer of electricity after lighting.
        Over the last 20 year's school's electricity consumption has increased significantly
        and most of this increase is from greater use of ICT. In the last 2 or 3 years
        at most schools this consumption has started do drop as older less efficient ICT
        equipment is replaced with more modern faster more efficient ICT.
        </p>
        <p>
        There are two main ways you can reduce ICT electricity consumption,
        you can ensure desktops and laptops are turned off when not in use by
        setting a standby policy e.g. go to standby after 15 minutes of inactivity,
        and for servers, to replace the servers with more modern more efficient
        ones or by moving your servers to the cloud, both of which can
        pay your capital investment (purchase costs) in as little as a year as
        a result of reduced electricity costs.
        <p>
        The first chart groups the ICT usage by week across the whole year.
        Do you think this is the correct pattern for your school? Are the
        desktops and laptops switched off during holidays and at weekends?
        </p>
      <% end %>
      <% if @chart_type == :electricity_by_day_of_week_simulator_ict %>
        <p>The next chart shows ICT usage by day of the week:</p>
      <% end %>
      <% if @chart_type == :intraday_electricity_simulator_ict %>
        <p>
        The final chart shows the usage by time of day. The first shows the
        energy use across the year by time of day.
        </p>
        <p>
        Does this look about right for your school? Is ICT used throughout
        the day in your school? Are the laptops plugged in all the time
        or are they just recharged at the end of the day?
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_ict %>
      <p>
        Look at the three charts above, do you think they represent the ICT usage in your school?
      </p>
      <p>
        What happens if you upgrade the school's servers to more efficient servers?
      </p>
      <p>
        You can see the impact by going to the simulator ICT configuration and
        changing wattage of number of servers, desktops, or laptops.
        What happens if you make some changes - reducing the watts or the
        number of servers, desktops, or laptops? What happens if you increase them?
      </p>
      <p> <%= sim_link('#ict') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorElectricalHeatingAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_simulator_electrical_heating
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <h2>Heating Using Electricity:</h2>
      <% end %>
      <p>
      Energy Sparks electricity simulator attempts to calculate how much
      electricity is used for heating in a school. However, it is quite
      difficult for the simulator to estimate this accurately and
      requires as physical audit of the school to provide accurate values.
      This will involve someone from the school auditing what electrical
      equipment is used for heating in a school in the winter - these
      would typically be electric fan heaters, but sometimes also
      air source heat pumps.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
      Electrical heating using fan heaters can be very expensive compared with
      gas - perhaps 5 times more expensive. However, this depends if the fan
      heater is just being used to heat a localised area or a whole room.
      Generally, we would advise against using fan heaters in schools if possible
      as each heater might be cost &#163; 2 per day per heater, or cost &#163; 150
      across the course of a winter - probably 10 times more than the fan heater
      cost to buy. The only time we recommend fan heaters is for use in holidays
      if there are very few people in a school and it saves turning on the heating
      for a whole school.
      </p>
      <p> <%= sim_link('#electricheating') %> </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorSecurityLightingAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_simulator_security_lighting
  # intraday_electricity_simulator_security_lighting_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_simulator_security_lighting %>
        <% if @add_extra_markup %>
          <h2>Security Lighting:</h2>
        <% end %>
        <p>
        Security Lighting (the lights around the perimeter of a school) which
        come on at night can be quite expensive to maintain. Their energy consumption
        depends on how they are controlled (switched on and off) and the efficiency
        of the lighting itself.
        </p>
        <p>
        For the maximum energy efficiency Energy Sparks generally recommends PIR
        based security lighting, which only comes on when movement is detected as
        it can reduce consumption by more than 90% - it can also be more secure
        as intruders are often more likely to be deterred if lighting suddenly switches
        on, rather than is on all the time, as neighbours and passers-by are more
        likely to notice.
        </p>
        <p>
        In addition, switching to LED lighting often has very short paybacks because
        security lighting on a timer is on for about half the hours in a year.
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_security_lighting_kwh %>
      <p>
      Do you know how the lighting is controlled at your school? And, what type of
      lighting is it? Is it LED lighting - which is generally the most efficient?
      </p>
      <p> <%= sim_link('#securitylights') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorKitchenAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_kitchen
  # intraday_electricity_simulator_kitchen_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_kitchen %>
        <% if @add_extra_markup %>
          <h2>Kitchen:</h2>
        <% end %>
        <p>
        Energy Sparks is not very good at automatically determining the kitchen
        usage patterns from the smart meter data, and so this usage would be best
        achieved by a physical audit.
        </p>
        <p>
        Where cooking takes place on site it is important that the kitchen doesn't turn
        hobs and ovens on too early. They often turn everything on as soon as they arrive
        at the school every day at 8:00am, but don't use the appliances until much later
        perhaps 11:00am, so wasting electricity between 8:00am and 11:00am.
        </p>
        <p>
        To improve this, it is worth speaking to the kitchen staff about their procedures
        - do they know for example how long ovens take to heat up (typically 10 to 15 minutes).
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_kitchen_kwh %>
      <p>
      You could also consider asking them whether they can clean and turn off fridges
      and freezers over long holidays. Or, they could consolidate the contents of
      all their fridges/freezers and turn some of them off. Particularly over the
      summer holidays, there should be no reason why fridges are left on.
      </p>
      <p> <%= sim_link('#kitchen') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorAirConAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_air_conditioning
  # intraday_electricity_simulator_air_conditioning_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_air_conditioning %>
        <% if @add_extra_markup %>
          <h2>Air Conditioning:</h2>
        <% end %>
        <p>
        If you have air conditioning in your school, please contact Energy Sparks
        for advice on how to configure the simulator correctly as it needs
        specialist knowledge.
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_air_conditioning_kwh %>
        <p> <%= sim_link('#aircon') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorFloodLightingAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_flood_lighting
  # intraday_electricity_simulator_flood_lighting_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_flood_lighting %>
        <% if @add_extra_markup %>
          <h2>Flood Lighting</h2>
        <% end %>
        <p>
        Flood lighting can be very expensive to run as the lights consume significant
        amounts of power, often more than the rest of the appliances in a school put
        together. There aren't many solutions for making them more efficient. Our
        main advice would be to make sure you are charging users an economic rate
        to cover the costs.
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_flood_lighting_kwh %>
        <p> <%= sim_link('#floodlighting') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorBoilerPumpAdvice < SimulatorApplianceAdviceBase
  # group_by_week_electricity_simulator_boiler_pump
  # intraday_electricity_simulator_boiler_pump_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_simulator_boiler_pump %>
        <% if @add_extra_markup %>
          <h2>Boiler Pumps</h2>
        <% end %>
        <p>
        Boiler pumps used for central heating and hot water can be significant
        consumers of electricity in a school. However, there is little you
        can do to make them more efficient unless the pumps in your school
        are old - more modern pumps have built in controls to optimise
        the flow rates and can save electricity. You can often see the
        consumption of boiler pumps if the electricity usage at the school
        jumps in the early morning on the winter - look at some of the
        dashboard graphs to see if you can spot this?
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_boiler_pump_kwh %>
        <p> <%= sim_link('#boilerpumps') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorSolarAdvice < SimulatorApplianceAdviceBase
    # group_by_week_electricity_simulator_solar_pv
  # intraday_electricity_simulator_solar_pv_kwh
  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :group_by_week_electricity_simulator_solar_pv %>
        <% if @add_extra_markup %>
          <h2>Solar PV</h2>
        <% end %>
        <p>
        By installing solar PV (photovoltaics) it is possible to reduce the mains electricity consumption
        at a school. The simulator represents solar PV as negative energy. It can be fun to play with
        the solar PV configuration to see the impact solar PV might have at your school?
        </p>
        <p>
        The graphs below show how much solar PV is consumed onsite, and how much is exported offsite.
        Generally, unless a school has a large amount of solar PV, exporting of electricity (when the PV
        is generating more than the school is consuming) only occurs on sunny days when the school is unoccupied.
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :intraday_electricity_simulator_solar_pv_kwh %>
        <p>
        At what time of year and time of the day do you get the most energy from solar PV panels?
        Which month of the year is most solar PV electricity exported to the grid? And, why?
        </p>
        <p> <%= sim_link('#solarpv') %> </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class SimulatorMiscOtherAdvice < SimulatorApplianceAdviceBase
end
