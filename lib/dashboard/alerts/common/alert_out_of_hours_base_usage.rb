#======================== Base: Out of hours usage ============================
require_relative 'alert_analysis_base.rb'
require 'erb'

class AlertOutOfHoursBaseUsage < AlertAnalysisBase
  include Logging

  attr_reader :fuel, :fuel_description, :fuel_cost
  attr_reader :significant_out_of_hours_use
  attr_reader :good_out_of_hours_use_percent, :bad_out_of_hours_use_percent, :out_of_hours_percent
  attr_reader :holidays_kwh, :weekends_kwh, :schoolday_open_kwh, :schoolday_closed_kwh, :community_kwh
  attr_reader :total_annual_kwh, :out_of_hours_kwh
  attr_reader :holidays_percent, :weekends_percent, :schoolday_open_percent, :schoolday_closed_percent, :community_percent
  attr_reader :percent_out_of_hours
  attr_reader :holidays_£, :weekends_£, :schoolday_open_£, :schoolday_closed_£, :out_of_hours_£, :community_£
  attr_reader :holidays_co2, :weekends_co2, :schoolday_open_co2, :schoolday_closed_co2, :out_of_hours_co2, :community_co2
  attr_reader :daytype_breakdown_table
  attr_reader :percent_improvement_to_exemplar, :potential_saving_kwh, :potential_saving_£, :potential_saving_co2
  attr_reader :total_annual_£, :total_annual_co2, :summary

  def initialize(school, fuel, benchmark_out_of_hours_percent,
                 alert_type, bookmark, meter_definition,
                 good_out_of_hours_use_percent, bad_out_of_hours_use_percent)
    super(school, alert_type)
    @fuel = fuel
    @fuel_description = fuel.to_s
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
      total_annual_co2: {
        description: 'Annual total fuel emissions (co2)',
        units: :co2
      },

      schoolday_open_kwh:   { description: 'Annual school day open kwh usage',   units: fuel_kwh },
      schoolday_closed_kwh: { description: 'Annual school day closed kwh usage', units: fuel_kwh },
      holidays_kwh:         { description: 'Annual holiday kwh usage',           units: fuel_kwh },
      weekends_kwh:         { description: 'Annual weekend kwh usage',           units: fuel_kwh },
      community_kwh:        { description: 'Annual community kwh usage',         units: fuel_kwh },
      total_annual_kwh:     { description: 'Annual kwh usage',                   units: fuel_kwh },
      out_of_hours_kwh:     { description: 'Annual kwh out of hours usage',      units: fuel_kwh },

      schoolday_open_percent:   { description: 'Annual school day open percent usage',    units: :percent, benchmark_code: 'sdop' },
      schoolday_closed_percent: { description: 'Annual school day closed percent usage',  units: :percent, benchmark_code: 'sdcp' },
      holidays_percent:         { description: 'Annual holiday percent usage',            units: :percent, benchmark_code: 'holp' },
      weekends_percent:         { description: 'Annual weekend percent usage',            units: :percent, benchmark_code: 'wkep' },
      community_percent:        { description: 'Annual community percent usage',          units: :percent, benchmark_code: 'comp' },
      out_of_hours_percent:     { description: 'Percent of kwh usage out of school hours',units: :percent},

      schoolday_open_£:         { description: 'Annual school day open cost usage',   units: :£ },
      schoolday_closed_£:       { description: 'Annual school day closed cost usage', units: :£ },
      holidays_£:               { description: 'Annual holiday cost usage',           units: :£, benchmark_code: 'ahl£' },
      weekends_£:               { description: 'Annual weekend cost usage',           units: :£, benchmark_code: 'awk£' },
      community_£:              { description: 'Annual community cost usage',         units: :£, benchmark_code: 'com£' },
      out_of_hours_£:           { description: 'Annual £ out ofS hours usage',        units: :£, benchmark_code: 'aoo£' },

      schoolday_open_co2:         { description: 'Annual school day open emissions',   units: :co2 },
      schoolday_closed_co2:       { description: 'Annual school day closed emissions', units: :co2 },
      holidays_co2:               { description: 'Annual holiday emissions',           units: :co2 },
      weekends_co2:               { description: 'Annual weekend emissions',           units: :co2 },
      community_co2:              { description: 'Annual community emissions',         units: :co2 },
      out_of_hours_co2:           { description: 'Annual out of hours emissions',      units: :co2 },

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
      potential_saving_co2: {
        description: 'annual co2 kg reduction if move to examplar out of hours usage',
        units: :co2,
      },
      summary: {
        description: 'Description: £spend/yr, percent out of hours',
        units: String
      },
      daytype_breakdown_table: {
        description: 'Table broken down by school day in/out hours, weekends, holidays - kWh, percent, £ (annual), CO2',
        units: :table,
        header: [ 'Day type', 'kWh', 'Percent', '£', 'co2' ],
        column_types: [String, {kwh: fuel}, :percent, :£, :co2 ]
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
    @holidays_kwh         = daytype_breakdown[SeriesNames::HOLIDAY]
    @weekends_kwh         = daytype_breakdown[SeriesNames::WEEKEND]
    @schoolday_open_kwh   = daytype_breakdown[SeriesNames::SCHOOLDAYOPEN]
    @schoolday_closed_kwh = daytype_breakdown[SeriesNames::SCHOOLDAYCLOSED]
    community_name        = OpenCloseTime.humanize_symbol(OpenCloseTime::COMMUNITY)
    @community_kwh        = daytype_breakdown[community_name] || 0.0

    @total_annual_kwh = @holidays_kwh + @weekends_kwh + @schoolday_open_kwh + @schoolday_closed_kwh + @community_kwh
    @out_of_hours_kwh = @total_annual_kwh - @schoolday_open_kwh

    # will need adjustment for Centrica - TODO
    @out_of_hours_percent = @out_of_hours_kwh / @total_annual_kwh

    @holidays_percent         = @holidays_kwh         / @total_annual_kwh
    @weekends_percent         = @weekends_kwh         / @total_annual_kwh
    @schoolday_open_percent   = @schoolday_open_kwh   / @total_annual_kwh
    @schoolday_closed_percent = @schoolday_closed_kwh / @total_annual_kwh
    @community_percent        = @community_kwh        / @total_annual_kwh

    @holidays_£         = @holidays_kwh         * tariff
    @weekends_£         = @weekends_kwh         * tariff
    @schoolday_open_£   = @schoolday_open_kwh   * tariff
    @schoolday_closed_£ = @schoolday_closed_kwh * tariff
    @out_of_hours_£     = @schoolday_closed_£ + @weekends_£ + @holidays_£
    @community_£        = @community_kwh * tariff
    @total_annual_£     = @holidays_£ + @weekends_£ + @schoolday_open_£ + @schoolday_closed_£

    @holidays_co2         = @holidays_kwh         * co2_intensity_per_kwh
    @weekends_co2         = @weekends_kwh         * co2_intensity_per_kwh
    @schoolday_open_co2   = @schoolday_open_kwh   * co2_intensity_per_kwh
    @schoolday_closed_co2 = @schoolday_closed_kwh * co2_intensity_per_kwh
    @community_co2        = @community_kwh        * co2_intensity_per_kwh
    @out_of_hours_co2     = @schoolday_closed_co2 + @weekends_co2 + @holidays_co2
    @total_annual_co2     = @holidays_co2 + @weekends_co2 + @schoolday_open_co2 + @schoolday_closed_co2

    @daytype_breakdown_table = [
      [SeriesNames::HOLIDAY,          @holidays_kwh,         @holidays_percent,          @holidays_£,         @holidays_co2],
      [SeriesNames::WEEKEND,          @weekends_kwh,         @weekends_percent,          @weekends_£,         @weekends_co2],
      [SeriesNames::SCHOOLDAYOPEN,    @schoolday_open_kwh,   @schoolday_open_percent,    @schoolday_open_£,   @schoolday_open_co2],
      [SeriesNames::SCHOOLDAYCLOSED,  @schoolday_closed_kwh, @schoolday_closed_percent,  @schoolday_closed_£, @schoolday_closed_co2]
    ]

    if @school.community_usage?
      community_row = [community_name,  @community_kwh, @community_percent,  @community_£, @community_co2]
      @daytype_breakdown_table.push(community_row)
    end

    @table_results = :daytype_breakdown_table # only used for backwards compatibility 17Mar19 - can be removed at some point
    @chart_results = out_of_hours_energy_consumption  # only used for backwards compatibility 17Mar19 - can be removed at some point

    @percent_improvement_to_exemplar = [out_of_hours_percent - good_out_of_hours_use_percent, 0.0].max
    @potential_saving_kwh = @total_annual_kwh * @percent_improvement_to_exemplar
    @potential_saving_£ = @potential_saving_kwh * tariff
    @potential_saving_co2 = @potential_saving_kwh * co2_intensity_per_kwh

    set_savings_capital_costs_payback(Range.new(@potential_saving_£, @potential_saving_£), nil, @potential_saving_co2)

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
      formatted_cost = sprintf('£%.0f', consumption[0] * tariff)
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
            <th scope="col" class="text-center">CO2 kg</th>
          </tr>
        </thead>
        <tbody>
          <% data.each do |row, usage, cost, co2| %>
            <tr>
              <td><%= row %></td>
              <td class="text-right"><%= usage %></td>
              <td class="text-right"><%= cost %></td>
              <td class="text-right"><%= co2 %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end
end
