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
    if ENV['School Dashboard Advice'] == 'Include Header and Body'
      @body_start = '<html><head>'
      @body_end = '</html></head>'
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

    header_template = %{<p>The school spent <%= electric_usage %> on electricity and <%= gas_usage %> on gas last year.</p><p>The electricity usage <%= electric_comparison %>.</p><p>The gas usage <%= gas_comparison %>: </p>}

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
            There is very no difference in energy consumption between older and newer schools in terms of
            energy consumption. The best schools from an energy efficiency perspective are those which
            manage there energy best, minimising out of hours usage and through good energy behaviour.
          <% end %>
        </p>
    }

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
          <%= table_info %>
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
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
      <table class="table table-striped table-sm">
        <thead>
          <tr class="thead-dark">
            <th scope="col">Type &#47; Time of Day </th>
            <th scope="col" class="text-center">kWh &#47; year </th>
            <th scope="col" class="text-center">&pound; &#47;year </th>
            <th scope="col" class="text-center">CO2 kg &#47;year </th>
            <th scope="col" class="text-center">Library Books &#47;year </th>
            <th scope="col" class="text-center">Percent </th>
          </tr>
        </thead>
        <tbody>
          <% data.each do |row, value| %>
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
    }
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
          <p>
            The graph below shows your <%= @fuel_type_str %> over the last year.
            Its shows how <%= @fuel_type_str %> varies throughout the year.
            It highlights how energy consumption generally increases in the
            winter and is lower in the summer.
          </p>
          <% if fuel_type == :gas %>
            <p>
            The blue line on the graph shows the number of 'degrees days' which is a measure
            of how cold it was during each week (the inverse of temperature - an
              <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a>) .
            If the heating boiler is working well at a school the blue line should track the gas usage quite closely.
            Look along the graph, does the usage (bars) track the degree days well?
            </p>
          <% else %>
          <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        The colouring on the graph also demonstrates whether
        <% if fuel_type == :gas %>
          The colouring on the graph also demonstrates whether heating and hot water were left on in the holidays.
          Try looking along the graph for the holidays highlighted in red - during which holidays was gas being
          consumed? Generally has heating and hot water should be turned off during holidays (<energy expert link>).
          It isn't necessary to leave everything on, and if someone is working in the school it is more
          efficient just to heat that room (fan heater) than the whole school. More than half of schools leave
          their heating on on Christmas Day - did your school do this, and was there anyone at school then?
        </p>
        <p>
          Sometimes the school building manager or caretaker is concerned about the school getting too
          cold and causing frost damage. This is a very rare event, and because most school boilers can
          be programmed to automatically (called 'frost protection') turn on in very cold weather
          it is unnecessary to leave the boiler on all holiday. If the school boiler doesn't have automatic
          'frost protection' then the thermostat at the school should be turned down as low as possible
          to 8C - this will save 70% of the gas compared with leaving the thermostat at 20C.
        <% else %>
          The colouring of the graph highlights electricity usage over holidays in red. Holiday usage
          is normally caused by appliances and computers being left on (called 'baseload'). The school
          should aim to reduce this baseload (which also occurs at weekends and overnight during school days) as
          reducing will have a big impact on a school's energy costs. Sometime this can be achieved by
          switching appliances off on Fridays before weekends and holidays, and sometimes by replacing
          consumers of electricity by more efficient ones.
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
      <p>
        The scatter chart below shows a thermostatic analysis of the school's heating system.
        The y axis shows the energy consumption in kWh on any given day.
        The x axis the number of degrees days (the inverse of temperature - so how cold it is
        <a href="https://www.carbontrust.com/media/137002/ctg075-degree-days-for-energy-management.pdf" target="_blank">explanation here</a> .
        Each point represents a single day, the colours represent different types of days.
        e.g. a day in the winter when the building is occupied and the heating is on.
      </p>
      <p>
        If the heating has good thermostatic control then the points at the top of
        chart when the heating is on and the school occupied should be close to the trend line.
        This is because the amount of heating required on a single day is linearly proportional to
        the difference between the inside and outside temperature, and any variation from the
        trend line would suggest thermostatic control isn't working too well.
      </p>
    }

    @header_advice = generate_html(header_template, binding)

    footer_template = %{<p> </p>}

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
        <p>
          The graph below shows your <%= @fuel_type_str %> broken down by
          day of the week over the last year:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        <% if fuel_type == :gas %>
          For most schools there should be no gas usage at weekends. The only reason gas might
          be used is for frost protection in very cold weather, and averaged across the whole
          year this should be a very small proportion of weekly usage.
          </p>
          <p>
          For schools made of heavy materials (thermally massive e.g. concrete block - known as
          masonary) sometimes there is more gas consumption on a Monday and Tuesday than Wednesday, Thursday and Friday, as additional energy is required to heat a school up after the heating
          is left off at weekends. This energy is being absorbed into the masonary.
          </p>
          <p>
          Can you see this pattern at your school from the graph above?<br>
          However, its still much more efficient to turn the heating off over the
          weekend, and use a little bit more energy on Monday and Tuesday than it is
          to leave the heating on all weekend.
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
