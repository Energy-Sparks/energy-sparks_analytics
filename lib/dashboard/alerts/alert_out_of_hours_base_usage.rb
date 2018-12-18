#======================== Base: Out of hours usage ============================
require_relative 'alert_analysis_base.rb'
require 'erb'

class AlertOutOfHoursBaseUsage < AlertAnalysisBase
  include Logging

  def initialize(school, fuel, benchmark_out_of_hours_percent,
                 fuel_cost, alert_type, bookmark, meter_definition)
    super(school)
    @fuel = fuel
    @benchmark_out_of_hours_percent = benchmark_out_of_hours_percent
    @fuel_cost = fuel_cost
    @alert_type = alert_type
    @bookmark = bookmark
    @meter_definition = meter_definition
  end

  def analyse(_asof_date)
    breakdown = out_of_hours_energy_consumption(@fuel)

    kwh_in_hours, kwh_out_of_hours = in_out_of_hours_consumption(breakdown)
    percent = kwh_out_of_hours / (kwh_in_hours + kwh_out_of_hours)

    report = AlertReport.new(@alert_type)
    report.term = :longterm
    report.add_book_mark_to_base_url(@bookmark)

    if percent > @benchmark_out_of_hours_percent
      report.summary = 'You have a high percentage of your ' + @fuel + ' usage outside school hours'
      text = sprintf('%.0f percent of your ' + @fuel, 100.0 * percent)
      text += ' is used out of hours which is high compared with exemplar schools '
      text += sprintf('which use only %.0f percent out of hours', 100.0 * @benchmark_out_of_hours_percent)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.add_detail(description1)
      description2 = AlertDescriptionDetail.new(:chart, breakdown)
      report.add_detail(description2)
      table_data = convert_breakdown_to_html_compliant_array(breakdown)

      description3 = AlertDescriptionDetail.new(:html, html_table_from_data(table_data))
      report.add_detail(description3)
      report.rating = 2.0
      report.status = :poor
    else
      report.summary = 'Your out of hours ' + @fuel + ' consumption is good'
      text = sprintf('Your out of hours ' + @fuel + ' consumption is good at %.0f percent', 100.0 * percent)
      description1 = AlertDescriptionDetail.new(:text, text)
      report.add_detail(description1)
      report.rating = 10.0
      report.status = :good
    end
    add_report(report)
  end

  def convert_breakdown_to_html_compliant_array(breakdown)
    html_table = []
    breakdown[:x_data].each do |daytype, consumption|
      formatted_consumption = sprintf('%.0f kWh', consumption[0])
      formatted_cost = sprintf('£%.0f', consumption[0] * @fuel_cost)
      html_table.push([daytype, formatted_consumption, formatted_cost])
    end
    html_table
  end

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

  def out_of_hours_energy_consumption(fuel)
    daytype_breakdown = {
        name: 'Day Type',
        chart1_type: :pie,
        series_breakdown: :daytype,
        yaxis_units: :£,
        yaxis_scaling: :none,
        meter_definition: fuel.to_sym == :electricity ? :allelectricity : :allheat,
        x_axis: :nodatebuckets,
        timescale: :year
    }

    # use the chart manager (and aggregator) to produce the breakdown
    chart = ChartManager.new(@school)
    result = chart.run_chart(daytype_breakdown, :daytype_breakdown)

    logger.debug result.inspect
    result
  end

  def generate_html(template, binding)
    begin
      rhtml = ERB.new(template)
      rhtml.result(binding)
    rescue StandardError => e
      logger.error "Error generating html for #{self.class.name}"
      logger.error e.message
      '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
    end
  end

  def html_table_from_data(data)
    template = %{
      <table class="table table-striped table-sm" id="alert-table-#{@alert_type}">
        <thead>
          <tr class="thead-dark">
            <th scope="col">Out of hours</th>
            <th scope="col" class="text-center">Energy usage</th>
            <th scope="col" class="text-center">Cost &pound;</th>
          </tr>
        </thead>
        <tbody>
          <% data.each do |row, usage, cost| %>
            <tr>
              <td><%= row %></td>
              <td class="text-right"><%= usage %></td>
              <td class="text-right"><%= cost %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end

end