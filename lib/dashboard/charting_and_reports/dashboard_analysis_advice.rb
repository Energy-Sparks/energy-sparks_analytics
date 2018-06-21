# generates advice for the dashboard in a mix of text, html and charts
# primarily bound up with specific charts, indexed by the symbol which represents
# the chart in chart_manager.rb e.g. :benchmark
# generates advice with different levels of expertise
require 'html-table'
require 'erb'

class DashboardEnergyAdvice
  def initialize
  end

  def self.advice(school, chart_definition, chart_data, chart_symbol)
    case chart_symbol
    when :benchmark
      advice = BenchmarkComparisonAdvice(school, chart_definition, chart_data, chart_symbol)
    else
      raise EnergySparksUnexpectedStateException.new("Dashboard advice requested for unsupported chart #{chart_symbol}")
    end
    advice.generate_advice(:energy_expert)
  end
end

class DashboardChartAdviceBase
  attr_reader :header_advice, :footer_advice, :body_start, :body_end
  def initialize(school, chart_definition, chart_data, chart_symbol)
    @school = school
    @chart_definition = chart_definition
    @chart_data = chart_data
    @chart_symbol = chart_symbol
    @header_advice = nil
    @footer_advice = nil
    @add_extra_markup = ENV['School Dashboard Advice'] == 'Include Header and Body'
    if @add_extra_markup
      @body_start = '<html><head>'
      @body_end = '</head></html>'
    else
      @body_start = ''
      @body_end = ''
    end
  end

  def self.advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :benchmark
      BenchmarkComparisonAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :thermostatic
      ThermostaticAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :cusum
      CusumAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :daytype_breakdown_electricity
      ElectricityDaytypeAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :daytype_breakdown_gas
      GasDaytypeAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_electricity
      ElectricityWeeklyAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_gas
      GasWeeklyAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_by_day_of_week
      ElectricityDayOfWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_by_day_of_week
      GasDayOfWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :baseload, :baseload_lastyear
      ElectricityBaseloadAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_by_month_year_0_1
      ElectricityMonthOnMonth2yearAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :intraday_line_school_days
      ElectricityLongTermIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol, :school_days)
    when :intraday_line_holidays
      ElectricityLongTermIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol, :holidays)
    when :intraday_line_weekends
      ElectricityLongTermIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol, :weekends)
    when :intraday_line_school_days_last5weeks, :intraday_line_school_days_6months, :intraday_line_school_last7days
      ElectricityShortTermIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    end
  end

  def generate_advice
    raise EnergySparksUnexpectedStateException.new('Error: unexpected call to DashboardChartAdviceBase abstract base class')
  end

protected

  def generate_html(template, binding)
    begin
      rhtml = ERB.new(template)
      rhtml.result(binding)
      # rhtml.gsub('£', '&pound;')
    rescue StandardError => e
      puts "Error generating html for {self.class.name}"
      puts e.message
      '<h2>Error generating advice</h2>'
    end
  end

  def percent(value)
    (value * 100.0).round(0).to_s + '%'
  end

  def pounds_to_pounds_and_kwh(pounds, fuel_type_sym)
    scaling = YAxisScaling.new
    kwh_conv = scaling.scale_unit_from_kwh(:£, fuel_type_sym)
    kwh = YAxisScaling.scale_num(pounds / kwh_conv)

    '&pound;' + YAxisScaling.scale_num(pounds) + ' (' + kwh + 'kWh)'
  end
end

#==============================================================================
class BenchmarkComparisonAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    puts @school.name
    electric_usage = get_energy_usage('electricity', :electricity, 0)
    gas_usage = get_energy_usage('gas', :gas, 0)

    electric_comparison = comparison('electricity', :electricity)
    gas_comparison = comparison('gas', :gas)

    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <h1>Energy Dashboard for <%= @school.name %></title></h1>
        <body>
      <% end %>
      <p>
        <%= @school.name %> is a <%= @school.school_type %> school near <%= @school.address %>
        with <%= @school.number_of_pupils %> pupils
        and a floor area of <%= @school.floor_area %>m<sup>2</sup>.
      </p>
      <p>
        The school spent <%= electric_usage %> on electricity
        and <%= gas_usage %> on gas last year.
        The electricity usage <%= electric_comparison %>.
        The gas usage <%= gas_comparison %>:
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <p>
        Your gas usage is <%= percent_regional_gas_str %> of the regional average which
        <% if percent_gas_of_regional_average < 0.7 %>
          is very good.
        <% elsif percent_gas_of_regional_average < 1.0 %>
          while although good, could be improved, better schools achieve 70% of the regional average,
          which would save you <%= pound_gas_saving_versus_benchmark %> per year.
        <% else %>
          is above average, the school should aim to reduce this,
          which would save you <%= pound_gas_saving_versus_benchmark %> per year
          if you matched the usage of energy efficient schools.
        <% end %>
        Your electricity usage is <%= percent_regional_electricity_str %> of the regional average which
        <% if percent_electricity_of_regional_average < 0.7 %>
          is very good.
        <% elsif percent_electricity_of_regional_average < 1.0 %>
          while although good, could be improved, better schools achieve 70% of the regional average,
            which would save you <%= pound_electricity_saving_versus_benchmark %> per year.
        <% else %>
          is above average, the school should aim to reduce this,
          which would save you <%= pound_electricity_saving_versus_benchmark %> per year
          if you matched the usage of energy efficient schools.
        <% end %>
      </p>
      <p>
        <% if percent_gas_of_regional_average < 0.7 && percent_electricity_of_regional_average < 0.7 %>
          Well done you energy usage is very low and you should be congratulated for being an energy efficient school.
        <% else %>
          There is very little difference in energy consumption between older and newer schools
          in terms of energy consumption. The best schools from an energy efficiency perspective
          are those which manage their energy best,
          minimising out of hours usage and demonstrating good energy behaviour.
        <% end %>
      </p>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  def actual_electricity_usage
    @chart_data[:x_data]['electricity'][0]
  end

  def actual_gas_usage
    @chart_data[:x_data]['gas'][0]
  end

  def percent_gas_of_regional_average
    actual_gas_usage / benchmark_gas_usage
  end

  def percent_electricity_of_regional_average
    actual_electricity_usage / benchmark_electricity_usage
  end

  def percent_regional_gas_str
    percent(percent_gas_of_regional_average)
  end

  def percent_regional_electricity_str
    percent(percent_electricity_of_regional_average)
  end

  def benchmark_electricity_usage
    @chart_data[:x_data]['electricity'][-1]
  end

  def pound_gas_saving_versus_benchmark
    pounds = actual_gas_usage - benchmark_gas_usage
    pounds_to_pounds_and_kwh(pounds, :gas)
  end

  def pound_electricity_saving_versus_benchmark
    pounds = actual_electricity_usage - benchmark_electricity_usage
    pounds_to_pounds_and_kwh(pounds, :electricity)
  end

  def benchmark_gas_usage
    @chart_data[:x_data]['gas'][-1]
  end

  def comparison(type_str, type_sym)
    spent = get_energy_usage(type_str, type_sym, -1)
    if @chart_data[:x_data][type_str][0] > @chart_data[:x_data][type_str][-1]
      'is more than similar regional schools which spent ' + spent
    else
      'is less than similar regional schools which spent ' + spent
    end
  end

  def get_energy_usage(type_str, type_sym, index)
    pounds = @chart_data[:x_data][type_str][index]
    pounds_to_pounds_and_kwh(pounds, type_sym)
  end

end

#==============================================================================
class FuelDaytypeAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  BENCHMARK_PERCENT = 0.5
  EXEMPLAR_PERCENT = 0.25
  def initialize(school, chart_definition, chart_data, chart_symbol, fuel_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @fuel_type = fuel_type
    @fuel_type_str = @fuel_type.to_s
  end

  def generate_advice
    kwh_in_hours, kwh_out_of_hours = in_out_of_hours_consumption(@chart_data)
    percent_value = kwh_out_of_hours / (kwh_in_hours + kwh_out_of_hours)
    percent_str = percent(percent_value)
    saving_percent = percent_value - 0.25
    saving_kwh = (kwh_in_hours + kwh_out_of_hours) * saving_percent
    saving_£ = YAxisScaling.convert(:kwh, :£, @fuel_type, saving_kwh)

    table_info = html_table_from_graph_data(@chart_data[:x_data], @fuel_type)

    header_template = %{
      <%= @body_start %>
        <p>
          <%= percent(percent_value) %> of your <% @fuel_type_str %> usage is out of hours:
        </p>
        <p>
          which is <%= adjective(percent_value, BENCHMARK_PERCENT) %>
          of <%= percent(BENCHMARK_PERCENT) %>.
          <% if percent_value > EXEMPLAR_PERCENT %>
            The best schools only
            consume <%= percent(EXEMPLAR_PERCENT) %> out of hours.
            Reducing the school's out of hours usage to <%= percent(EXEMPLAR_PERCENT) %>
            would save &pound;<%= saving_£ %> per year.
          <% else %>
            which is very good, and is one of the best schools.
          <% end %>
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
      <%= table_info %>
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  def adjective(percent, percent_benchmark, above_sense = true, the = true)
    diff = (percent - percent_benchmark) * (above_sense ? 1 : -1)
    the_average = (the ? ' the' : '') + ' average'
    if diff < 0.05 && diff > -0.05
      'about' + the_average
    elsif diff >= 0.05 && diff < 0.1
      'above' + the_average
    elsif diff >= 0.1
      'well above' + the_average
    elsif diff <= -0.05 && diff > -0.1
      'below' + the_average
    else
      'well below' + the_average
    end
  end

  def html_table_from_graph_data(data, fuel_type = :electricity, totals_row = true)
    total = 0.0
    data.each_value do |value|
      total += value[0]
    end
    template = %{
    <style>
      tr:nth-child(even) {background-color: #e4f0c2;}
      .tg .tg-numeric{text-align:right}
      th {
        background-color: #4CAF50;
        color: white;
      }
      .estbtrbold {
        font-weight: bold;
      }
    </style>
    <centre>
      <table class="tg">
        <tr>
          <th> Type &#47; Time of Day </th>
          <th> kWh &#47; year </th>
          <th> &pound; &#47;year </th>
          <th> CO2 kg &#47;year </th>
          <th> Library Books &#47;year </th>
          <th> Percent </th>
        </tr>
        <% data.each do |row, value| %>
          <tr>
            <td><%= row %></td>
            <% val = value[0] %>
            <% pct = val / total %>
            <td class="tg-numeric"><%= YAxisScaling.scale_num(val) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :£, fuel_type, val) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :co2, fuel_type, val) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :library_books, fuel_type, val) %></td>
            <td class="tg-numeric"><%= percent(pct) %></td>
          </tr>
        <% end %>

        <% if totals_row %>
          <tr class="estbtrbold">
            <td><b>Total</b></td>
            <td class="tg-numeric"><%= YAxisScaling.scale_num(total) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :£, fuel_type, total) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :co2, fuel_type, total) %></td>
            <td class="tg-numeric"><%= YAxisScaling.convert(:kwh, :library_books, fuel_type, total) %></td>
            <td></td>
          </tr>
        <% end %>
      </tr>
      </table>
      </centre>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end

  # copied from alerts code, needs rationalising
  def in_out_of_hours_consumption(breakdown)
    kwh_in_hours = 0.0
    kwh_out_of_hours = 0.0
    breakdown[:x_data].each do |daytype, consumption|
      if daytype == SeriesNames::SCHOOLDAYOPEN
        kwh_in_hours += consumption[0]
      else
        kwh_out_of_hours += consumption[0]
      end
    end
    [kwh_in_hours, kwh_out_of_hours]
  end
end

#==============================================================================
class ElectricityDaytypeAdvice < FuelDaytypeAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :electricity)
  end
end
#==============================================================================
class GasDaytypeAdvice < FuelDaytypeAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :gas)
  end
end

#==============================================================================
class WeeklyAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  BENCHMARK_PERCENT = 0.5
  EXEMPLAR_PERCENT = 0.25
  def initialize(school, chart_definition, chart_data, chart_symbol, fuel_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @fuel_type = fuel_type
    @fuel_type_str = @fuel_type.to_s
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <body>
          <p>
            The graph below shows how your <%= @fuel_type_str %> consumption varies throughout the year.
            It highlights how <%= @fuel_type_str %> consumption generally increases in the winter and is lower in the summer.
          </p>
            <% if fuel_type == :gas %>
              The blue line on the graph shows the number of 'degrees days' which is a measure of how cold
              it was during each week  (the inverse of temperature - an
                <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a>) .
                If the heating boiler is working well at your school the blue line should track the gas usage quite closely.
                Look along the graph, does the usage (bars) track the degree days well?
            <% else %>
            <% end %>
          <p>

          </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <% if fuel_type == :gas %>
          The colouring on the graph also demonstrates whether heating and hot water were left on in the holidays.
          Try looking along the graph for the holidays highlighted in red - during which holidays was gas being consumed?
          Generally gas heating and hot water should be turned off during holidays. It isn't necessary to leave everything on,
          and if someone is working in the school it is more efficient just to heat that room (fan heater) than the whole school.
          More than half of schools leave their heating on on Christmas Day - did your school do this, and was there anyone at school then?
        </p>
        <p>
          Sometimes the school building manager or caretaker is concerned about the school getting too cold
          and causing frost damage. This is a very rare event, and because most school boilers can be programmed
          to automatically turn on in very cold weather  (called 'frost protection') it is unnecessary
          to leave the boiler on all holiday. If the school boiler doesn't have automatic
          'frost protection' then the thermostat at the school should be turned down as low as possible to 8C
          - this will save 70% of the gas compared with leaving the thermostat at 20C.
        <% else %>
          The colouring on the graph also highlights electricity usage over holidays in red.
          Holiday usage is normally caused by appliances and computers being left on (called 'baseload').
          The school should aim to reduce this baseload (which also occurs at weekends
          and overnight during school days) as this will have a big impact on a school's energy costs.
          Sometime this can be achieved by switching appliances off on Fridays before weekends and holidays,
          and sometimes by replacing older appliances consuming electricity by more efficient ones.

          </p>
          <p>
            For example replacing 2 old ICT servers which run a schools computer network which perhaps
            consume 1,500 watts of electricity, to a single more efficient server consuming 500 watts
            would reduce power consumption by 1,000 watts (1.0 kW) on every day of the year.
            This would save 1kW x 24 hours per day x 365 days per year = 8,760 kWh. Each kWh of electricity
            costs about 12p, so this would save 8,760 x 12p = &pound;1,050 per year. If the new server lasted
            5 years then that would be a &pound;5,250 saving to the school which is far more than the
            likely &pound;750 cost of the new server!
        <% end %>
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class ElectricityWeeklyAdvice < WeeklyAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :electricity)
  end
end
#==============================================================================
class GasWeeklyAdvice < WeeklyAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :gas)
  end
end
#==============================================================================
class ThermostaticAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    puts @school.name
    header_template = %{
      <html>
        <head><h2>Thermostatic analysis</title></h2>
        <body>
          <p>
            The scatter chart below shows a thermostatic analysis of the school's heating system.
            The y axis shows the energy consumption in kWh on any given day.
            The x axis the number of degrees days (the inverse of temperature) - so how cold it is
            <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a> .
            Each point represents a single day, the colours represent different types of days
            .e.g. a day in the winter when the building is occupied and the heating is on.
          </p>
          <p>
            If the heating has good thermostatic control then the points at the top of
            chart when the heating is on and the school occupied should be close to the trend line.
            This is because the amount of heating required on a single day is linearly proportional to
            the difference between the inside and outside temperature, and any variation from the
            trend line would suggest thermostatic control isn't working too well.
          </p>
        </body>
      </html>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    alert = AlertThermostaticControl.new(@school)
    alert_description = alert.analyse(@school.aggregated_heat_meters.amr_data.end_date)
    # :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area
    ap(alert_description)
    r2_status = alert_description.detail[0].content
    a = alert.a.round(0)
    b = alert.b.round(0)
    base_temp = alert.base_temp

    url = 'http://blog.minitab.com/blog/adventures-in-statistics-2/regression-analysis-how-do-i-interpret-r-squared-and-assess-the-goodness-of-fit'
    footer_template = %{
      <html>
        <p>
        One measure of how well the thermostatic control at the school is working is
        the mathematical value R^2
        (<a href="<%= url %>" target="_blank">explanation here</a>)
        which is a measure of how far the points are
        from the trend line. A perfect R^2 of 1.0 would mean all the points were on the line,
        if points appear as a cloud with no apparent pattern (random) then the R^2 would
        be close to 1.0. For heating systems in schools a good value is 0.8.
        </p>
        <p>
          <%= r2_status  %>
        </p>
        <p>
        For energy experts, the formula which defines the trend line is very interesting.
        It predicts how the gas consumption varies with how cold it is (degree days).
        </p>
        <p>
          In the example above the formula is:
          <blockquote>
            predicted_heating_requirement = <%= a %> + <%= b %> * degree_days
          </blockquote>
          Degree days is calculated as follows
          <blockquote>
          degree_days = max(<%= base_temp %> - average_temperature_for_day, 0)
          </blockquote>
          So for your school if the average outside temperature is 12C (8 degree days)
          the predicted gas consumption for the school would be
          <%= (a + b * (base_temp - 12)).round(0) %> kWh for the day. Where as if the outside
          temperature was colder at 4C the gas consumption would be
          <%= (a + b * (base_temp - 4)).round(0) %> kWh. See if you can read these values
          off the trend line of the graph above (degree days on the x axis and the answer -
          the predicted daily gas consumption on the y-axis). Does your reading match
          with the answers for 12C and 4C above?
        </p>
      </html>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class CusumAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    puts @school.name
    header_template = %{
      <html>
        <head><h2>Cusum analysis</title></h2>
        <body>
          <p>
          <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">Cusum (culmulative sum) graphs</a>
          shows how the school's actual gas consumption differs
          from the predicted gas consumption (see the explanation about the
          formula for the trend line in the thermostatic graph above).
          </p>
          <p>
          The graph is used my energy assessors to help them understand why a school's heating system
          might not be working well. It also allows them to see if changes in a school like
          a new more efficient boiler or reduced classroom temperatures has reduced gas consumption
          as it removes the variability caused by outside temperature from the graph.
          </p>
        </body>
      </html>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    alert = AlertThermostaticControl.new(@school)
    alert_description = alert.analyse(@school.aggregated_heat_meters.amr_data.end_date)
    a = alert.a.round(0)
    b = alert.b.round(0)

    footer_template = %{
      <html>
        <p>
          Each point is calculated by subtracting the school's actual
          gas consumption from the value calculated from the trend
          line in the thermostatic scatter plot above. i.e.
          <blockquote>
            cusum_value = actual_gas_consumption - predicted_gas_consumption
          </blockquote>
          which for this school is
          <blockquote>
            cusum_value = actual_gas_consumption - <%= a %> + <%= b %> * degree_days
          </blockquote>
        </p>
      </html>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class DayOfWeekAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  ELECTRICITY_WEEKEND_PERCENT_BENCHMARK = 0.15
  ELECTRICITY_WEEKEND_PERCENT_EXEMPLAR = 0.10
  GAS_WEEKEND_PERCENT_BENCHMARK = 0.05
  GAS_WEEKEND_PERCENT_EXEMPLAR = 0.01
  def initialize(school, chart_definition, chart_data, chart_symbol, fuel_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @fuel_type = fuel_type
    @fuel_type_str = @fuel_type.to_s
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <body>
          <p>
            The graph below shows your <%= @fuel_type_str %> broken down by
            day of the week over the last year:
          <p>

          </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <% if fuel_type == :gas %>
          For most schools there should be no gas usage at weekends. The only reason gas
          might be used is for frost protection in very cold weather,
          and averaged across the whole year this should be a very small
          proportion of weekly usage
          </p>
          <p>
          For schools made of thermally massive materials e.g. masonry or concrete blocks
          sometimes there is more gas consumption on a Monday and Tuesday than Wednesday,
          Thursday and Friday, as additional energy is required to heat a school up after
          the heating is left off at weekends.
          This energy is being absorbed into the masonry
          </p>
          </p>
          Can you see this pattern at your school from the graph above?<br>
          However, it's still much more efficient to turn the heating off over the weekend,
          and use a little bit more energy on Monday and Tuesday than it is to leave
          the heating on all weekend.
        <% else %>
          There will be some electricity usage at weekends from appliances and devices
          left on, but the school should aim to minimise these. Schools with low weekend
          electricity consumption aim to switch as many appliances off as possible
          on a Friday afternoon, sometimes providing the caretaker or cleaning
          staff with a checklist as to what they should be turning off.
        <% end %>
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class ElectricityDayOfWeekAdvice < DayOfWeekAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :electricity)
  end
end

#==============================================================================
class GasDayOfWeekAdvice < DayOfWeekAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :gas)
  end
end

#==============================================================================
class ElectricityBaseloadAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
    @fuel_type = fuel_type
    @fuel_type_str = @fuel_type.to_s
  end

  def generate_advice
    alert = AlertElectricityBaseloadVersusBenchmark.new(@school)
    alert_description = alert.analyse(@school.aggregated_electricity_meters.amr_data.end_date)
    # :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area
    ap(alert_description)
puts alert_description.detail[0].content
    header_template = %{
      <%= @body_start %>
        <body>
          <p>
            The graph below shows how the the school's electricity 'baseload'
            (out of hours electricity consumption) has varied over time:
          </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <%= alert_description.summary %>.
        <%= alert_description.detail[0].content %>
        Reducing a school's baseload is often the fastest way of reducing a school's energy costs
        and reducing its carbon footprint. For each 1kW reduction in baseload, the school will save
        £1,050 per year, and reduce its carbon footprint by 2,400 kg.
      </p>
      <p>
        Look carefully at the graph above, how has the baseload changed over time?
        Does it change seasonally (from summer to winter)? There should be very
        little difference between summer and winter electricity baseload, unless
        there is something not working properly at the school, for example
        electrical heating accidently left on?
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class ElectricityLongTermIntradayAdvice < DashboardChartAdviceBase
  attr_reader :type
  def initialize(school, chart_definition, chart_data, chart_symbol, type)
    super(school, chart_definition, chart_data, chart_symbol)
    @type = type
    case @type
    when :school_days
      @period = 'on school days'
    when :weekends
      @period = 'at the weekend'
    when :holidays
      @period = 'during the holidays'
    end
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      This graph compares the average power consumption
      at the school during the last 2 years <%= @period %>.
      <% if type == :school_days %>
      It shows the peak power usage at the school (normally during
        the middle of the day) and the overnight power consumption.
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>

      <% if type == :school_days %>
      <p>
      It is useful in diagnosing what changes have happened over the
      the last year which may have changed electricity consumption.
      </p>
      <p>
      At most schools the overnight consumption between 7:00pm in the
      evening and 6:00am in the morning is relatively constant. Is this
      the case at you school? There are a few reasons why there might
      be a small change during the night e.g. central heating boiler
      pumps sometimes on cold nights in the winter (frost protection)
      but any significant change should be investigated as you might be
      able to save electricity and costs through fixing the problem.
      </p>
      <p>
      During the day electricity power consumption rises rapidly and
      often peaks around midday.
      </p>
      <p>
      See if you can spot some of the following typical characteristics in the
      chart:
      <ul>
      <li>
        Electricity consumption starting to increase from about 7:00am
        when the the school opens, and lights and computers are switched
        on rapidly increasing consumption. What time does your school
        open and who is first to arrive?
      </li>
      <li>
          Its often possible to see when cleaners arrive at the school,
          in some schools its in the morning before school opens,
          at others its in the evening after school closes. Can you
          spot the cleaners on the chart? Its common for cleaners to
          switch all the school lights on; its possible to save electricity
          by asking them to only turn the lights on in the rooms they are cleaning
      </li>
      <li>
        The highest point on the charts is often around lunchtime
        when all the school lights and computers are switched on.
        You can often see a peak between 11:30am and 1:00pm when
        hot plates are switched on for school meals. Can you see
        a jump in consumption of between 2kW and 4kW at this time
        which might be the hot plates?
      </li>
      <li>
          After the school closes there should be a gradual reduction
          in electricity consumption as teachers leave and lights
          and computers are switched off
      </li>
      <li>
          Sometimes there is a regular evening event which increases consumption
      </li>
      </ul>
      </p>
      <% elsif type == :weekends || type == :holidays %>
      <p>
          The graph above shows <%= @period %> consumption. At most schools this
          should be relatively constant <%= @period %>, unless:
          <ul>
          <li>
          The school is occupied <%= @period %> when consumption might increase
          during the day
          </li>
          <li>
          The school has solar panels which might cause consumption to drop
          during the middle of the day when the sun is out
          </li>
          <li>
          The school has security lights which causes consumption to rise
          overnight when the sun goes down
          </li>
          </ul>
          Can you see any of these characteristics at your school
          in the graph above?
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class ElectricityMonthOnMonth2yearAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      The graph below compares monthly electricity consumption over the two years.
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
      Its sometimes a useful comparison, however you need to be careful when
      comparing months with holidays, particularly Easter, which some years
      is in March and other times in April.
      </p>
      <p>
      Try comparing the monthly consumption over the last 2 years
      to see if there are any difference you can explains?
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class ElectricityShortTermIntradayAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
    case @chart_type
    when :intraday_line_school_days_last5weeks
      @period = 'last 5 weeks'
    when :intraday_line_school_days_6months
      @period = '2 weeks 6 months apart'
    when :intraday_line_school_last7days
      @period = 'last 7 days'
    end
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <p>
      The graph below shows how the consumption varaies
      during the day over the last <%= @period %>.
      </p>
      <p>
      You can use this type of graph to understand how the schools electricity usage changes
      over time, between differing days of the week, or over longer periods.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% case @chart_type
          when :intraday_line_school_days_last5weeks %>
      <p>
      This graph shows the change in average school day electricity consumption
      over the last 5 weeks. Take a look at the graphs and compare the
      different weeks. If there are changes from one week to the next can
      you think of a reason why these might have occurred? One of the most
      obvious changes might be if one of these weeks was a holiday when
      you would see much lower power consumption.
      <\p>
      <p>
      It can be useful to understand why there has been a change in consumption
      as you can learn from this, by understanding what affects your electricity
      consumption to reduce consumption permanently, or at least stop it from
      increasing.
      </p>
      <% when :intraday_line_school_days_6months %>
      This graph compares 2 weeks average consumption during the day 6 months apart.
      <p>
      </p>
      <% when :intraday_line_school_last7days %>
      <p>
      </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
