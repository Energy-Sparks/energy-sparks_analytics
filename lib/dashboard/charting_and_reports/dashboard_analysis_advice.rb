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
  attr_reader :header_advice, :footer_advice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    puts "GGGGGGG", chart_data
    @school = school
    @chart_definition = chart_definition
    @chart_data = chart_data
    @chart_symbol = chart_symbol
    @header_advice = nil
    @footer_advice = nil
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

    header_template = %{
      <html>
        <head><h1>Energy Dashboard for <%= @school.name %></title></h1>
        <body>
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
        </body>
      </html>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <html>
        <p>
        However, the best performing schools used 30% less fuel than the regional average.
        It is also important to realise even at older schools it is possible to make
        significant energy reductions and are often more energy efficient than newer schools.
        </p>
      </html>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
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

    scaling = YAxisScaling.new
    kwh_conv = scaling.scale_unit_from_kwh(:£, type_sym)
    kwh = YAxisScaling.scale_num(pounds / kwh_conv)

    '&pound;' + YAxisScaling.scale_num(pounds) + ' (' + kwh + 'kWh)'
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
