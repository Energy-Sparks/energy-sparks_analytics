#======================== Base: Out of hours usage ============================
require_relative 'alert_analysis_base.rb'
require 'erb'

class AlertOutOfHoursBaseUsage < AlertAnalysisBase
  include Logging

  attr_reader :fuel, :fuel_description, :fuel_cost
  attr_reader :significant_out_of_hours_use
  attr_reader :good_out_of_hours_use_percent, :bad_out_of_hours_use_percent, :out_of_hours_percent
  attr_reader :holidays_kwh, :weekends_kwh, :schoolday_open_kwh, :schoolday_closed_kwh
  attr_reader :total_annual_kwh, :out_of_hours_kwh
  attr_reader :holidays_percent, :weekends_percent, :schoolday_open_percent, :schoolday_closed_percent
  attr_reader :percent_out_of_hours
  attr_reader :holidays_£, :weekends_£, :schoolday_open_£, :schoolday_closed_£, :out_of_hours_£
  attr_reader :daytype_breakdown_table
  attr_reader :percent_improvement_to_exemplar, :potential_saving_kwh, :potential_saving_£
  attr_reader :total_annual_£, :summary

  def initialize(school, fuel, benchmark_out_of_hours_percent,
                 fuel_cost, alert_type, bookmark, meter_definition,
                 good_out_of_hours_use_percent, bad_out_of_hours_use_percent)
    super(school, alert_type)
    @fuel = fuel
    @fuel_description = fuel.to_s
    @fuel_cost = fuel_cost
    @bookmark = bookmark
    @good_out_of_hours_use_percent = good_out_of_hours_use_percent
    @bad_out_of_hours_use_percent = bad_out_of_hours_use_percent
    @meter_definition = meter_definition
    @chart_results = nil
    @table_results = nil
    @relevance = :never_relevant if @relevance != :never_relevant && aggregate_meter.amr_data.days_valid_data < 364
  end

  def self.static_template_variables(fuel)
    fuel_kwh = { kwh: fuel}
    @template_variables = {
      fuel: {
        description: 'Fuel type (this alert analysis is shared between electricity and gas)',
        units:  Symbol
      },
      fuel_description: {
        description: 'Fuel description (electricity or gas)',
        units:  String
      },
      fuel_cost: {
        description: 'Fuel cost p/kWh',
        units:  :£_per_kwh
      },
      total_annual_£: {
        description: 'Annual total fuel cost (£)',
        units: :£
      },

      schoolday_open_kwh:   { description: 'Annual school day open kwh usage',   units: fuel_kwh },
      schoolday_closed_kwh: { description: 'Annual school day closed kwh usage', units: fuel_kwh },
      holidays_kwh:         { description: 'Annual holiday kwh usage',           units: fuel_kwh },
      weekends_kwh:         { description: 'Annual weekend kwh usage',           units: fuel_kwh },
      total_annual_kwh:     { description: 'Annual kwh usage',                   units: fuel_kwh },
      out_of_hours_kwh:     { description: 'Annual kwh out of hours usage',      units: fuel_kwh },

      schoolday_open_percent:   { description: 'Annual school day open percent usage',    units: :percent, benchmark_code: 'sdop' },
      schoolday_closed_percent: { description: 'Annual school day closed percent usage',  units: :percent, benchmark_code: 'sdcp' },
      holidays_percent:         { description: 'Annual holiday percent usage',            units: :percent, benchmark_code: 'holp' },
      weekends_percent:         { description: 'Annual weekend percent usage',            units: :percent, benchmark_code: 'wkep' },
      out_of_hours_percent:     { description: 'Percent of kwh usage out of school hours',units: :percent},

      schoolday_open_£:         { description: 'Annual school day open cost usage',   units: :£ },
      schoolday_closed_£:       { description: 'Annual school day closed cost usage', units: :£ },
      holidays_£:               { description: 'Annual holiday cost usage',           units: :£, benchmark_code: 'ahl£' },
      weekends_£:               { description: 'Annual weekend cost usage',           units: :£, benchmark_code: 'awk£' },
      out_of_hours_£:           { description: 'Annual £ out of hours usage',         units: :£, benchmark_code: 'aoo£' },

      good_out_of_hours_use_percent: {
        description: 'Good/Exemplar out of hours use percent (suggested benchmark comparison)',
        units:  :percent
      },
      bad_out_of_hours_use_percent: {
        description: 'High out of hours use percent (suggested benachmark comparison)',
        units:  :percent
      },
      significant_out_of_hours_use: {
        description: 'Significant out of hours usage',
        units:  TrueClass
      },
      percent_improvement_to_exemplar:  {
        description: 'percent improvement in out of hours usage to exemplar',
        units:  :percent
      },
      potential_saving_kwh: {
        description: 'annual kwh reduction if move to examplar out of hours usage',
        units: :kwh
      },
      potential_saving_£: {
        description: 'annual £ reduction if move to examplar out of hours usage',
        units: :£,
        benchmark_code: 'esv£'
      },
      summary: {
        description: 'Description: £spend/yr, percent out of hours',
        units: String
      },
      daytype_breakdown_table: {
        description: 'Table broken down by school day in/out hours, weekends, holidays - kWh, percent, £ (annual)',
        units: :table,
        header: [ 'Day type', 'kWh', 'Percent', '£' ],
        column_types: [String, {kwh: fuel}, :percent, :£ ]
      }
    }
  end

  def timescale
    'last year'
  end

  def enough_data
    days_amr_data >= 364 ? :enough : :not_enough
  end

  def calculate(_asof_date)
    raise EnergySparksNotEnoughDataException, "Not enough data: 1 year of data required, got #{days_amr_data} days" if enough_data == :not_enough
    daytype_breakdown = extract_kwh_from_chart_data(out_of_hours_energy_consumption)
    @holidays_kwh         = daytype_breakdown['Holiday']
    @weekends_kwh         = daytype_breakdown['Weekend']
    @schoolday_open_kwh   = daytype_breakdown['School Day Open']
    @schoolday_closed_kwh = daytype_breakdown['School Day Closed']

    @total_annual_kwh = @holidays_kwh + @weekends_kwh + @schoolday_open_kwh + @schoolday_closed_kwh
    @out_of_hours_kwh = @total_annual_kwh - @schoolday_open_kwh

    @out_of_hours_percent = @out_of_hours_kwh / @total_annual_kwh

    @holidays_percent         = @holidays_kwh         / @total_annual_kwh
    @weekends_percent         = @weekends_kwh         / @total_annual_kwh
    @schoolday_open_percent   = @schoolday_open_kwh   / @total_annual_kwh
    @schoolday_closed_percent = @schoolday_closed_kwh / @total_annual_kwh

    @holidays_£         = @holidays_kwh         * @fuel_cost
    @weekends_£         = @weekends_kwh         * @fuel_cost
    @schoolday_open_£   = @schoolday_open_kwh   * @fuel_cost
    @schoolday_closed_£ = @schoolday_closed_kwh * @fuel_cost
    @out_of_hours_£     = @schoolday_closed_£ + @weekends_£ + @holidays_£
    @total_annual_£     = @holidays_£ + @weekends_£ + @schoolday_open_£ + @schoolday_closed_£

    @daytype_breakdown_table = [
      ['Holiday',            @holidays_kwh,         @holidays_percent,          @holidays_£],
      ['Weekend',            @weekends_kwh,         @weekends_percent,          @weekends_£],
      ['School Day Open',    @schoolday_open_kwh,   @schoolday_open_percent,    @schoolday_open_£],
      ['School Day Closed',  @schoolday_closed_kwh, @schoolday_closed_percent,  @schoolday_closed_£]
    ]

    @table_results = :daytype_breakdown_table # only used for backwards compatibility 17Mar19 - can be removed at some point
    @chart_results = out_of_hours_energy_consumption  # only used for backwards compatibility 17Mar19 - can be removed at some point

    @percent_improvement_to_exemplar = [out_of_hours_percent - good_out_of_hours_use_percent, 0.0].max
    @potential_saving_kwh = @total_annual_kwh * @percent_improvement_to_exemplar
    @potential_saving_£ = @potential_saving_kwh * @fuel_cost

    set_savings_capital_costs_payback(Range.new(@potential_saving_£, @potential_saving_£), nil)

    @summary = summary_text

    @rating = calculate_rating_from_range(good_out_of_hours_use_percent, bad_out_of_hours_use_percent, out_of_hours_percent)

    @significant_out_of_hours_use = @rating < 7.0

    @status = @significant_out_of_hours_use ? :bad : :good

    @term = :longterm
    @bookmark_url = add_book_mark_to_base_url(@bookmark)
  end
  alias_method :analyse_private, :calculate

  def summary_text
    FormatEnergyUnit.format(:£, @out_of_hours_£, :text) + 'pa (' +
    FormatEnergyUnit.format(:percent, @out_of_hours_percent, :text) + ' of annual cost) '
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

  def extract_kwh_from_chart_data(breakdown)
    breakdown[:x_data].each_with_object({}) { |(daytype, linedata), hash| hash[daytype] = linedata[0] }
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

  def out_of_hours_energy_consumption
    chart = ChartManager.new(@school)
    chart.run_standard_chart(breakdown_chart, nil, true)
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
