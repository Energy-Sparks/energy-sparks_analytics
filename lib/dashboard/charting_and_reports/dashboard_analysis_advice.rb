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
  include Logging

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
    when :gas_heating_season_intraday
      GasHeatingIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_electricity
      ElectricityWeeklyAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_electricity_unlimited, :group_by_week_gas_unlimited
      WeeklyLongTermAdvice.new(school, chart_definition, chart_data, chart_symbol)
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
    when :frost_1,  :frost_2,  :frost_3
      HeatingFrostAdviceAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when :thermostatic_control_large_diurnal_range_1,  :thermostatic_control_large_diurnal_range_2,  :thermostatic_control_large_diurnal_range_3
      HeatingThermostaticDiurnalRangeAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when :optimum_start
      HeatingOptimumStartAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when :hotwater
      HotWaterAdvice.new(school, chart_definition, chart_data, chart_symbol, chart_type)
    when :electricity_simulator_pie
      ElectricitySimulatorBreakdownAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_simulator_pie_detail_page
      ElectricitySimulatorDetailBreakdownAdvice.new(school, chart_definition, chart_data, chart_symbol)
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
      logger.error "Error generating html for #{self.class.name}"
      logger.error e.message
      '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
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

  def kwh_to_pounds_and_kwh(kwh, fuel_type_sym)
    pounds = YAxisScaling.convert(:kwh, :£, fuel_type_sym, kwh, false)
    logger.debug pounds.inspect
    logger.debug kwh.inspect
    '&pound;' + YAxisScaling.scale_num(pounds) + ' (' + YAxisScaling.scale_num(kwh) + 'kWh)'
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
            <th scope="col" class="text-center">Library Books &#47;year </th>
            <th scope="col" class="text-center">Percent </th>
          </tr>
        </thead>
        <tbody>
          <% sorted_data.each do |row, value| %>
            <tr>
              <td><%= row %></td>
              <% val = value[0] %>
              <% pct = val / total %>
              <td class="text-right"><%= YAxisScaling.scale_num(val) %></td>
              <td class="text-right"><%= YAxisScaling.convert(:kwh, :£, fuel_type, val) %></td>
              <td class="text-right"><%= YAxisScaling.convert(:kwh, :co2, fuel_type, val) %></td>
              <td class="text-right"><%= YAxisScaling.convert(:kwh, :library_books, fuel_type, val) %></td>
              <td class="text-right"><%= percent(pct) %></td>
            </tr>
          <% end %>

          <% if totals_row %>
            <tr class="table-success">
              <td><b>Total</b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.scale_num(total) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(:kwh, :£, fuel_type, total) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(:kwh, :co2, fuel_type, total) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(:kwh, :library_books, fuel_type, total) %></b></td>
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
class BenchmarkComparisonAdvice < DashboardChartAdviceBase
  include Logging

  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    logger.info @school.name
    electric_usage = get_energy_usage('electricity', :electricity, index_of_most_recent_date)
    gas_usage = get_energy_usage('gas', :gas, index_of_most_recent_date)

    address = @school.postcode.nil? ? @school.address : @school.postcode

    electric_comparison_regional = comparison('electricity', :electricity, index_of_data("Regional Average"))
    gas_comparison_regional = comparison('gas', :gas, index_of_data("Regional Average"))

    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <h1>Energy Dashboard for <%= @school.name %></title></h1>
        <body>
      <% end %>
      <p>
        <%= @school.name %> is a <%= @school.school_type %> school near <%= address %>
        with <%= @school.number_of_pupils %> pupils
        and a floor area of <%= @school.floor_area %>m<sup>2</sup>.
      </p>
      <p>
        Your school spent <%= electric_usage %> on electricity
        and <%= gas_usage %> on gas last year.
        The electricity usage <%= electric_comparison_regional %>.
        The gas usage <%= gas_comparison_regional %>:
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <p>
      <% if actual_gas_usage > 0 %>
        Your gas usage is <%= percent(percent_gas_of_regional_average) %> of the regional average which
        <% if actual_gas_usage < exemplar_gas_usage %>
          is very good.
        <% else %>
          <% if actual_gas_usage < average_regional_gas_usage %>
            while although good, could be improved
          <% else %>
            is above average, the school should aim to reduce this,
          <% end %>
          which would save you <%= pound_gas_saving_versus_exemplar %> per year if you matched the most energy efficient (exemplar) schools.
        <% end %>
      <% end %>
      <% if actual_electricity_usage > 0 %>
        Your electricity usage is <%= percent(percent_electricity_of_regional_average) %> of the regional average which
        <% if actual_electricity_usage < exemplar_electricity_usage %>
          is very good.
        <% else %>
          <% if actual_electricity_usage < average_regional_electricity_usage %>
            while although good, could be improved
          <% else %>
            is above average, the school should aim to reduce this,
          <% end %>
          which would save you <%= pound_electricity_saving_versus_exemplar %> per year if you matched the most energy efficient (exemplar) schools.
        <% end %>
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
    @chart_data[:x_data]['electricity'][index_of_most_recent_date]
  end

  def actual_gas_usage
    @chart_data[:x_data]['gas'][index_of_most_recent_date]
  end

  def average_regional_electricity_usage
    @chart_data[:x_data]['electricity'][index_of_data("Regional Average")]
  end

  def average_regional_gas_usage
    @chart_data[:x_data]['gas'][index_of_data("Regional Average")]
  end

  def exemplar_electricity_usage
    @chart_data[:x_data]['electricity'][index_of_data("Exemplar School")]
  end

  def exemplar_gas_usage
    @chart_data[:x_data]['gas'][index_of_data("Exemplar School")]
  end

  def percent_gas_of_regional_average
    actual_gas_usage / average_regional_gas_usage
  end

  def percent_electricity_of_regional_average
    actual_electricity_usage / average_regional_electricity_usage
  end

  def pound_gas_saving_versus_exemplar
    pounds = actual_gas_usage - exemplar_gas_usage
    pounds_to_pounds_and_kwh(pounds, :gas)
  end

  def pound_electricity_saving_versus_exemplar
    pounds = actual_electricity_usage - exemplar_electricity_usage
    pounds_to_pounds_and_kwh(pounds, :electricity)
  end

  def comparison(type_str, type_sym, with)
    spent = get_energy_usage(type_str, type_sym, with)
    if @chart_data[:x_data][type_str][index_of_most_recent_date] > @chart_data[:x_data][type_str][with]
      'is more than similar regional schools which spent ' + spent
    else
      'is less than similar regional schools which spent ' + spent
    end
  end

  def get_energy_usage(type_str, type_sym, index)
    pounds = @chart_data[:x_data][type_str][index]
    pounds_to_pounds_and_kwh(pounds, type_sym)
  end

  def index_of_data(name)
    @chart_data[:x_axis].find_index(name)
  end

  def index_of_most_recent_date
    converted_to_date_or_nil = []
    @chart_data[:x_axis].each do |series_name|
      converted_to_date_or_nil.push(parse_axis_date(series_name))
    end
    sorted_list = converted_to_date_or_nil.sort { |a,b| a && b ? b <=> a : b ? 1 : -1 } # newest date 1st, nils at end
    converted_to_date_or_nil.find_index(sorted_list[0])
  end

  def parse_axis_date(series_name)
    begin
      Date.Parse(series_name)
    rescue StandardError => _e
      nil
    end
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

    table_info = html_table_from_graph_data(@chart_data[:x_data], @fuel_type, true, 'Time Of Day')

    header_template = %{
      <%= @body_start %>
        <p>
          <%= percent(percent_value) %> of your <% @fuel_type_str %> usage is out of hours:
          which is <%= adjective(percent_value, BENCHMARK_PERCENT) %>
          of <%= percent(BENCHMARK_PERCENT) %>.
          <% if percent_value > EXEMPLAR_PERCENT %>
            The best schools only
            consume <%= percent(EXEMPLAR_PERCENT) %> out of hours.
            Reducing your school's out of hours usage to <%= percent(EXEMPLAR_PERCENT) %>
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
class WeeklyLongTermAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end
  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
        This graph shows he same information as the graph above but over a longer period of time.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
        Can you spot any difference or changes that have occurred over the last few years?
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class GasHeatingIntradayAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end
  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
        This graph shows how the gas consumption of the school varies on school days when the heating is on in the winter:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
        Its a useful graph for determining how well controlled the timing of the boiler is?
        A well timed boiler should only come on at about 6:00am in the morning
        to get the school up to temperature by 8:00am, and then turn off again about half
        and hour before the school closes.
        </p>
        <p>
        Does you school's boiler control in the graph above do this?
        Is the timing of the boiler 'well controlled'?
        If it isn't you might need to speak to your building manager or caretaker and
        ask why? There is lots of advice on our dashboard advice webpage about this.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
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
        <p>
          The graph below shows how your <%= @fuel_type_str %> consumption varies throughout the year.
          It highlights how <%= @fuel_type_str %> consumption generally increases in the winter and is lower in the summer.
        </p>

        <% if fuel_type == :gas %>
          <p>
            The blue line on the graph shows the number of 'degrees days' which is a measure of how cold
            it was during each week. Degree days are the inverse of temperature.
            The higher the degree days the lower the temperature. See a more detailed -
              <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a> .
              If the heating boiler is working well at your school the blue line should track the gas usage quite closely.
              Look along the graph, does the usage (bars) track the degree days well?
          </p>
        <% else %>
        <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <% if fuel_type == :gas %>
        <p>
          The colouring on the graph also demonstrates whether heating and hot water
          were left on in the holidays.
          Try looking along the graph for the holidays highlighted in red
          - during which holidays was gas being consumed?
          Generally gas heating and hot water should be turned off during holidays.
          It isn't necessary to leave everything on,
          and if someone is working in the school it is more efficient
          just to heat that room with a fan heater or similar than the whole school.
          More than half of schools leave their heating on on Christmas Day
          - did your school do this, and was there anyone at school then?
        </p>
        <p>
          Sometimes the school building manager or caretaker is concerned about the school getting too cold
          and causing frost damage. This is a very rare event, and because most school boilers can be programmed
          to automatically turn on in very cold weather  (called 'frost protection') it is unnecessary
          to leave the boiler on all holiday. If the school boiler doesn't have automatic
          'frost protection' then the thermostat at the school should be turned down as low as possible to 8C
          - this will save 70% of the gas compared with leaving the thermostat at 20C.
        </p>
        <% else %>
          <p>
          The colouring on the graph also highlights electricity usage over holidays in red.
          Holiday usage is normally caused by appliances and computers being left on (called 'baseload').
          The school should aim to reduce this baseload (which also occurs at weekends
          and overnight during school days) as this will have a big impact on a school's energy costs.
          Sometime this can be achieved by switching appliances off on Fridays before weekends and holidays,
          and sometimes by replacing older electrical appliances with more efficient new ones.
          </p>
          <p>
            For example replacing 2 old ICT servers which run a schools computer network which perhaps
            consume 1,500 watts of electricity, to a single more efficient server consuming 500 watts
            would reduce power consumption by 1,000 watts (1.0 kW) on every day of the year.
            This would save 1kW x 24 hours per day x 365 days per year = 8,760 kWh. Each kWh of electricity
            costs about 12p, so this would save 8,760 x 12p = &pound;1,050 per year. If the new server lasted
            5 years then that would be a &pound;5,250 saving to the school which is far more than the
            likely &pound;750 cost of the new server!
          </p>
        <% end %>
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
  include Logging

  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    logger.info @school.name
    header_template = %{
      <% if @add_extra_markup %>
        <html>
          <head><h2>Thermostatic analysis</h2>
          <body>
      <% end %>
          <p>
            A building with good thermostatic control means the heating system brings the temperature
            of  the building up to the set temperature, and then maintains it at a constant level.
            The heating required and therefore gas consumption varies linearly with how  cold it is outside.
            The heating system can adjust for internal heat gains due to people, electrical equipment and
            sunshine warming the building. It can also adjust for losses due to ventilation. Poor thermostatic
            control is likely to cause poor thermal comfort (uses feel too hot or too cold), and excessive gas
            consumption as the  thermal comfort is often maintained by leaving windows open.
          </p>
          <p>
            Unfortunately, many schools have poor thermostatic control. This can be due
            to poorly located boiler thermostats. A common location for a thermostat in schools
            is in the school hall or entrance lobby whose heating, internal gains and heat losses
            are not representative of the building as a whole, and particularly classrooms.
            Halls are often poorly insulated with few radiators which means they never get up to temperature,
            causing the boiler controller to run the boiler constantly which causes the better insulated
            classrooms to overheat.
          </p>
          <p>
            Poor thermostatic control can also be due to a lack of thermostatic controls in individual rooms,
            which leads to windows being opened to compensate.
          </p>

          <p>
            The scatter chart below shows a thermostatic analysis of your school's heating system.
            The y axis shows the energy consumption in kWh on any given day.
            The x axis the number of degrees days. This is inverse of temperature,
            the higher the degree days the colder the temperature.
            <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a> .
            Each point represents a single day, the colours represent different types of days
            .e.g. a day in the winter when the building is occupied and the heating is on.
          </p>
          <p>
            If the heating has good thermostatic control then the points at the top of
            chart when the heating is on and the school occupied should be close to the trend line (red squares).
            This is because the amount of heating required on a single day is linearly proportional to
            the difference between the inside and outside temperature, and any variation from the
            trend line would suggest thermostatic control isn't working too well.
          </p>

      <% if @add_extra_markup %>
          </body>
      <% end %>
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

    url = 'http://blog.minitab.com/blog/adventures-in-statistics-2/regression-analysis-how-do-i-interpret-r-squared-and-assess-the-goodness-of-fit'.freeze
    footer_template = %{
        <p>
        One measure of how well the thermostatic control at the school is working is
        the mathematical value R<sup>2</sup>
        (<a href="<%= url %>" target="_blank">explanation here</a>)
        which is a measure of how far the points are
        from the trend line. A perfect R<sup>2</sup> of 1.0 would mean all the points were on the line,
        if points appear as a cloud with no apparent pattern (random) then the R<sup>2</sup> would
        be close to 1.0. For heating systems in schools a good value is 0.8.
        </p>
        <p>
          <%= r2_status  %>
        </p>
        <p>
        For energy experts, the formula which defines the trend line is very interesting.
        It predicts how the gas consumption varies with how cold it is (degree days).
        </p>
        <p>In the example above the formula is:</p>

        <blockquote>predicted_heating_requirement = <%= a %> + <%= b %> * degree_days</blockquote>

        <p>Degree days is calculated as follows</p>

        <blockquote>degree_days = max(<%= base_temp %> - average_temperature_for_day, 0)</blockquote>
        <p>
          So for your school if the average outside temperature is 12C (8 degree days)
          the predicted gas consumption for the school would be
          <%= (a + b * (base_temp - 12)).round(0) %> kWh for the day. Where as if the outside
          temperature was colder at 4C the gas consumption would be
          <%= (a + b * (base_temp - 4)).round(0) %> kWh. See if you can read these values
          off the trend line of the graph above (degree days on the x axis and the answer -
          the predicted daily gas consumption on the y-axis). Does your reading match
          with the answers for 12C and 4C above?
        </p>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class CusumAdvice < DashboardChartAdviceBase
  include Logging
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    logger.debug @school.name
    header_template = %{
      <% if @add_extra_markup %>
        <html>
          <head><h2>Cusum analysis</h2>
          <body>
      <% end %>

        <p>
        <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">Cusum (culmulative sum) graphs</a>
        shows how the school's actual gas consumption differs
        from the predicted gas consumption (see the explanation about the
        formula for the trend line in the thermostatic graph above).
        </p>
        <p>
        The graph is used by energy assessors to help them understand why a school's heating system
        might not be working well. It also allows them to see if changes in a school like
        a new more efficient boiler or reduced classroom temperatures has reduced gas consumption
        as it removes the variability caused by outside temperature from the graph.
        </p>

      <% if @add_extra_markup %>
          </body>
        </html>
      <% end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    alert = AlertThermostaticControl.new(@school)
    alert_description = alert.analyse(@school.aggregated_heat_meters.amr_data.end_date)
    a = alert.a.round(0)
    b = alert.b.round(0) * 1.0

    footer_template = %{
      <% if @add_extra_markup %>
        <html>
      <% end %>
<% if false %>

        <p>
          Each point is calculated by subtracting the school's actual
          gas consumption from the value calculated from the trend
          line in the thermostatic scatter plot above. i.e.
        </p>
        <blockquote>cusum_value = actual_gas_consumption - predicted_gas_consumption</blockquote>

        <p>which for this school is</p>

        <blockquote>cusum_value = actual_gas_consumption - <%= a %> + <%= b %> * degree_days</blockquote>
<% end %>
      <% if @add_extra_markup %>
        </html>
      <% end %>
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
      <% if @add_extra_markup %>
        <body>
      <% end %>
        <p>
          The graph below shows your <%= @fuel_type_str %> use broken down by
          day of the week over the last year:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <% if fuel_type == :gas %>
          <p>
          For most schools there should be no gas usage at weekends. The only reason gas
          might be used is for frost protection in very cold weather,
          and averaged across the whole year this should be a very small
          proportion of weekly usage
          </p>
          <p>
          For some schools  there is more gas consumption on a Monday and Tuesday than Wednesday,
          Thursday and Friday, as additional energy is required to heat a school up after the heating
          is left off at weekends.
          This energy is being absorbed into the masonry.
          </p>
          <p>
          'Thermal mass' describes a material's capacity to absorb, store and release heat.
          For example, concrete has a high capacity to store heat and is referred to as a
          'high thermal mass' material. Insulation foam,
          by contrast, has very little heat storage capacity
          and is referred to as having 'low thermal mass'.
          </p>
          <p>
          Can you see this pattern at your school from the graph above?<br>
          It's still much more efficient to turn the heating off over the weekend,
          and use a little more energy on Monday and Tuesday than it is to leave
          the heating on all weekend.
          </p>
          <p>
          If the graph shows  high weekend gas consumption, ask your caretaker or building manager
          to check your heating system controls. You may have:
          </p>
          <ul>
            <li>incorrect or faulty frost protection</li>
            <li>lack a 7 day timer so it is not possible to  turn the heating off at weekends</li>
            <li>incorrect boiler settings</li>
          </ul>
          <p>
          By eliminating weekend gas consumption at your school you could save up to
          <%= kwh_to_pounds_and_kwh(weekend_saving_kwh, :gas) %> per year.
          </p>
        <% else %>
          <p>
          There will be some electricity usage at weekends from appliances and devices
          left on, but the school should aim to minimise these. Schools with low weekend
          electricity consumption aim to switch as many appliances off as possible
          on a Friday afternoon, sometimes providing the caretaker or cleaning
          staff with a checklist as to what they should be turning off.
          </p>
        <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  def weekend_saving_kwh
    total = 0.0
    @chart_data[:x_data].each do |_daytype, days_of_week|
      total += days_of_week[0] # Sunday
      total += days_of_week[6] # Saturday
    end
    total
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
  include Logging

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
    logger.debug alert_description.detail[0].content
    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <body>
      <% end %>
          <p>
            Electricity baseload is the electricity needed to provide power to appliances that keep running at all times.
            It can be measured by looking at your school's out of  hours electricity consumption.
            The graph below shows how your school's electricity 'baseload'
            has varied over time:
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
        electrical heating left on accidently?
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
      <p>
      This graph compares the average power consumption
      at the school during the last 2 years <%= @period %>.
      <% if type == :school_days %>
      It shows the peak power usage at the school (normally during
        the middle of the day) and the overnight power consumption.
      <% end %>
      </p>
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
      pumps sometimes runing on cold nights in the winter (frost protection)
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
      </p>
      <ul>
      <li>
        Electricity consumption starting to increase from about 7:00am
        when the school opens, and lights and computers are switched
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
      <% elsif type == :weekends || type == :holidays %>
      <p>
          The graph above shows consumption <%= @period %>. At most schools this
          should be relatively constant <%= @period %>, unless:
      </p>
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
          Electrical hot water heaters left on during the holidays causing
          peaks in consumption often in the morning, but sometimes throughout the day.
          </li>
          <li>
          The school has security lights which causes consumption to rise
          overnight when the sun goes down
          </li>
          <li>
          The school has electrical water heaters running through the weekend,
          which will cause peaks in consumption often in the morning, but
          sometimes  throughout the day.
          </li>
          </ul>
        <p>
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
      <p>The graph below compares monthly electricity consumption over the two years.</p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
      This graph allows you to see long term trends in energy use.
      It can be a quick way to spot whether  energy saving behaviour
      and lighting and equipment updates are having an impact on your electricity consumption.
      You need to be careful when comparing months with holidays, particularly Easter,
      which some years is in March and other times in April.
      </p>
      <p>
      Try comparing the monthly consumption over the last 2 years
      to see if there are any differences which you can explain?
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
      @period = 'the last 5 weeks'
    when :intraday_line_school_days_6months
      @period = '2 weeks 6 months apart'
    when :intraday_line_school_last7days
      @period = 'the last 7 days'
    end
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <p>
      The graph below shows how the consumption varies
      during the day over <%= @period %>.
      </p>
      <p>
      You can use this type of graph to understand how the schools electricity usage changes
      over time.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% case @chart_type
          when :intraday_line_school_days_last5weeks %>
      <p>
      Take a look at the graphs and compare the
      different weeks. If there are changes from one week to the next can
      you think of a reason why these might have occurred? One of the most
      obvious changes might be if one of these weeks was a holiday when
      you would see much lower power consumption.
      </p>
      <p>
      It can be useful to understand why there has been a change in consumption
      as you can learn from this. By understanding what affects your electricity
      consumption you can reduce consumption permanently, or at least stop it from
      increasing.
      </p>

      <% when :intraday_line_school_days_6months %>
      <p>
        This graph compares 2 weeks average consumption during the day 6 months apart.
        Its interesting as it allows you to see the difference between usage at 2 different times
        of the year, differences can include for example the amount of lighting consumption
        which impacts the peak usage during the day.
      </p>
      <% when :intraday_line_school_last7days %>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class HeatingFrostAdviceAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :frost_1 %>
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
        for these schools to leave their heating on during winter holidays, which is signifcantly more expensive
        than if frost protection is allowed to provide the protection automatically.
        </p>
        <p>
        The 3 graphs below which are for the coldest weekends of recent years, attempt to demonstate whether
        </p>
        <ol type="a">
        <li>Frost protection is configured for your school, and</li>
        <li>whether it is configured correctly and running efficiently</li>
        </ol>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :frost_1 %>
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
      <% if @chart_type == :frost_3 %>
        <p>
        The graphs can be difficult to interpret sometimes, so if you are uncertain about what
        you are seeing please contact us <a href="mailto:hello@energysparks.uk?subject=Boiler Frost Protection&">contact us</a>
        and we will look for you, and let you know what we think.
        think.
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
# for charts: :thermostatic_control_large_diurnal_range_1,
#             :thermostatic_control_large_diurnal_range_2
#             :thermostatic_control_large_diurnal_range_3
class HeatingThermostaticDiurnalRangeAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :thermostatic_control_large_diurnal_range_1 %>
        <p>
        Sometimes the 'thermostatic' scatter plot on the graph can be misleading, and
        thermostatic control is either better or worse than the R<sup>2</sup> suggests.
        </p>
        <p>
        An alternative way of looking at the thermostatic control is to look at whether
        a school's gas consumption changes on a day when the outside temperature changes
        signifcantly. It is common, particularly in Spring for outside temperatures to increase by
        more than 10C during the day (called a large diurnal temperature range, typically caused
        by a cold ground temperatures after the winter reducing overnight temperatures,
        and warm Spring sunshine during the day).
        In theory if outside temperatures rise by 10C, then the heating loss through a building's
        fabric (walls, windows etc.) will more than halve (as the heat loss is proportional
        to the difference between outside and inside temperatures). If the school has good thermostatic
        control then you would expect so see a similar drop in gas consumption over the course of
        the day.
        </p>
        <p>
        The 3 charts below show recent example winter days with a large diural range:
        </p>

      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :thermostatic_control_large_diurnal_range_1 %>
      <p>
        We can't automate this analysis, so you will need to look at the chart for you and
        decide: as the outside temperature rises (dark blue line), does the school's gas consumption
        drop signifcantly?
      </p>
      <% end %>
      <% if @chart_type == :thermostatic_control_large_diurnal_range_3 %>
        <p>
        Do any of these charts indicate there is poor thermostatic control? You would see this
        if the gas consumption varied little during the day?
        </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class HeatingOptimumStartAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :optimum_start %>
        <h4>Optimum Start Control? Or, is your boiler turning on too early or being left on too late??</h4>
        <p>
        Most modern commercial boilers used in schools support 'optimum start control' - this is
        where the boiler controller learns over time how long it takes to heat up a school
        depending on how cold it is outside and inside. This allows the boiler to be turned
        on later in the morning (e.g. 06:00am) in milder weather saving energy and earlier (e.g. 04:00am)
        in colder weather. Without this type of control's schools often set their heating
        to come on at a fixed time, often earlier in the day (e.g. 04:00am) just in case
        the weather is cold, but this is unnecessarily early in mild weather and wastes energy.
        </p>
        <p>
        If your boiler has optimum start control which is working well it could save
        up to 20% of your school's heating costs.
        </p>
        <p>
        However, optimum start control often goes wrong and starts the heating far too early in
        the morning wasting even more energy than those schools without it.
        </p>
        <p>
        The chart below compares 2 days, one colder than the other:
        </p>

      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :optimum_start %>
      <p>
        Does your school have optimum start control? If it does you would expect the boiler
        to start later on the milder day? Does it start earlier on the colder day?
      </p>
      <p>
      This graph is also useful in determining whether your boiler is starting at a reasonable
      time in the morning. It depends a little on the school, but for these 2 days you might expect
      the boiler to start at 5:30am on the colder day and perhaps 06:30am on the milder day. Is this
      the case for your school?
      </p>
      <p>
      Is the heating also turning off at a reasonable time, perhaps half an hour before school closing time?
      The school could save energy by ensuring the boiler turns off at the right time.
      </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end

#==============================================================================
class HotWaterAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  def initialize(school, chart_definition, chart_data, chart_symbol, chart_type)
    super(school, chart_definition, chart_data, chart_symbol)
    @chart_type = chart_type
  end

  def generate_advice
    avg_school_day_gas_consumption = hotwater_model.avg_school_day_gas_consumption
    avg_holiday_day_gas_consumption = hotwater_model.avg_holiday_day_gas_consumption
    avg_weekend_day_gas_consumption = hotwater_model.avg_weekend_day_gas_consumption
    annual_hotwater_kwh_estimate = hotwater_model.annual_hotwater_kwh_estimate
    benchmark_hotwater_kwh = AnalyseHeatingAndHotWater::HotwaterModel.benchmark_annual_pupil_kwh * @school.number_of_pupils
    annual_benchmark_saving = (annual_hotwater_kwh_estimate - benchmark_hotwater_kwh)
    _litres_savings = AnalyseHeatingAndHotWater::HotwaterModel.litres_of_hotwater(annual_benchmark_saving)
    baths_savings = AnalyseHeatingAndHotWater::HotwaterModel.baths_of_hotwater(annual_benchmark_saving)
    baths_savings = (baths_savings / 100.0).round(0) * 100.0
    baths_per_pupil = (baths_savings / @school.number_of_pupils).round(0)

    efficiency = hotwater_model.efficiency

    header_template = %{
      <%= @body_start %>
      <% if @chart_type == :hotwater %>
        <p>
        Hot water is schools is generally provided by a central gas boiler which then circulates
        the hot water around the school, or by more local electrically powered immersion
        or point of use heaters.
        </p>
        <p>
        This section of the dashboard attempts to help analysis gas based hot water heating
        where a gas boiler, generally in the boiler room circulates hot water around the
        school. These systems are often quite inefficient, because they circulate hot water
        permanently in a loop around the school so hot water is immediately available
        when someone turns on a tap rather than having to wait for the hot water to come
        all the way from the boiler room. The circulatory pipework used to do this is often
        poorly insulated, and loses heat. Often these types of systems are only 20% efficient
        compared with direct point of use water heaters which are often over 90% efficient.
        </p>
        <p>
        The graph below attempts to analyse your school's hot water system by looking
        at the heating over the course of the summer, just before and during the start
        of the summer holidays. If the hot water has been accidentally left on during the summer
        holidays, it is possible to see how efficient the hot water system is by
        comparing the difference in consumption between occupied and unoccupied days.
        </p>
        <p>
        The Energy Sparks analysis tries to automate this comparison, but sometimes doesn't get
        this right, as its much easier for a human to do this by looking at the graph.
          </p>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <% if @chart_type == :hotwater %>
      <p>
        Look at the graph, has the hot water been left on either during the summer holidays
        or at the weekend?
      </p>
      <p>
        The Energy Sparks automated analysis suggests the following:
      </p>
      <ul>
        <li>An average school day consumption of <%= YAxisScaling.scale_num(avg_school_day_gas_consumption) %> kWh</li>
        <li>An average weekend day consumption of <%= YAxisScaling.scale_num(avg_weekend_day_gas_consumption) %> kWh</li>
        <li>An average holiday day consumption of <%= YAxisScaling.scale_num(avg_holiday_day_gas_consumption) %> kWh</li>
        <li>Likely overall efficiency: <%= percent(efficiency * 0.6) %></li>
        <li>Estimate of annual cost for hot water: <%= kwh_to_pounds_and_kwh(annual_hotwater_kwh_estimate, :gas) %>
        <li>Benchmark annual usage for school of same size <%= YAxisScaling.scale_num(benchmark_hotwater_kwh) %> kWh (assumes 5 litres of hot water per pupil per day)</li>
        <li>If the school matched the annual benchmark consumption it would save the equivalent of <%= baths_savings %> baths
        of hot water every year, or <%= baths_per_pupil %> per pupil!</li>
      </ul>
      <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  def hotwater_model
    if @hotwater_model.nil?
      @hotwater_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@school)
    end
    @hotwater_model
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
        <h1>Electricity Simulator Results</h1>
        <p>
          Energy Sparks Electricity Simulator breaks down the electricity use within a school to different appliance types.
          Initially, it does this automatucally based on the existing smart meter data, and a knowledge of the consumption
          of appliances at other schools where we have undertaken a physically audit of appliances in the past.
          As such it is an 'educated guess' at how electricity is consumed in a school,
          and can be refined by an audit of a school's appliances which could be performed by pupils.
        </p>
        <p>
          The simulator is designed to help make more rational decisions when replacing appliances, for example it allows
          via the configuration editor you to answer the question 'How much would I save if I installed more energy efficient lighting?', or
          'How much would I save if I replaced the school's ICT servers with more efficient ones?
        </p>
        <p>
          For each appliance type, using a variety of external data (e.g. temperature, sunshine data and solar PV data) and
          occupancy patterns it assesses realistic usages for every <sup>1</sup>/<sup>2</sup> hour
          for each appliance type. The results are presented below.
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
      <p>
      </p>
        If you are using the simulator to make a decision about an investment in more efficient equipment, you
        should multiply the annual savings by the life of the investment typically 5 to 15 years.
      </p>
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
        <h1>Electricity Simulator Results Detailed Breakdown</h1>
        <p>
          Energy Sparks Electricity Simulator breaks down the electricity use within a school to different appliance types.
          Initially, it does this automatucally based on the existing smart meter data, and a knowledge of the consumption
          of appliances at other schools where we have undertaken a physically audit of appliances in the past.
          As such it is an 'educated guess' at how electricity is consumed in a school,
          and can be refined by an audit of a school's appliances which could be performed by pupils.
        </p>
        <p>
          The simulator is designed to help make more rational decisions when replacing appliances, for example it allows
          via the configuration editor you to answer the question 'How much would I save if I installed more energy efficient lighting?', or
          'How much would I save if I replaced the school's ICT servers with more efficient ones?
        </p>
        <p>
          For each appliance type, using a variety of external data (e.g. temperature, sunshine data and solar PV data) and
          occupancy patterns it assesses realistic usages for every <sup>1</sup>/<sup>2</sup> hour
          for each appliance type. The results are presented below.
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
      <p>
      </p>
        If you are using the simulator to make a decision about an investment in more efficient equipment, you
        should multiply the annual savings by the life of the investment typically 5 to 15 years.
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
