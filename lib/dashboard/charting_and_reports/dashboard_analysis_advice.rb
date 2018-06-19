# generates advice for the dashboard in a mix of text, html and charts
# primarily bound up with specific charts, indexed by the symbol which represents
# the chart in chart_manager.rb e.g. :benchmark
# generates advice with different levels of expertise
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
    rescue StandardError => e
      puts "Error generating html for {self.class.name}"
      puts e.message
      '<html><h2>Error generating advice</h2></html>'
    end
  end

  def pounds_to_pounds_and_kwh(pounds, fuel_type_sym)
    scaling = YAxisScaling.new
    kwh_conv = scaling.scale_unit_from_kwh(:£, fuel_type_sym)
    kwh = YAxisScaling.scale_num(pounds / kwh_conv)

    '&pound;' + YAxisScaling.scale_num(pounds) + ' (' + kwh + 'kWh)'
  end
end

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
            which would save you <%= pound_gas_saving_versus_benchmark %> per year if you matched the usage of exemplar schools.
          <% end %>
          Your electricity usage is <%= percent_regional_electricity_str %> of the regional average which
          <% if percent_electricity_of_regional_average < 0.7 %>
            is very good.
          <% elsif percent_electricity_of_regional_average < 1.0 %>
            while although good, could be improved, better schools achieve 70% of the regional average,
              which would save you <%= pound_electricity_saving_versus_benchmark %> per year.
          <% else %>
            is above average, the school should aim to reduce this,
            which would save you <%= pound_electricity_saving_versus_benchmark %> per year if you matched the usage of exemplar schools.
          <% end %>
          <% if percent_gas_of_regional_average < 0.7 && percent_electricity_of_regional_average < 0.7 %>
            Well done you energy usage is very low and you should be congratulated for being an exemplar school.
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

  def percent(value)
    (value * 100.0).round(0).to_s + '%'
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
            The x axis the number of degrees days (the inverse of temperature - so how cold it is
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

    footer_template = %{
      <html>
        <p>
          Looking at the model
        </p>
      </html>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
