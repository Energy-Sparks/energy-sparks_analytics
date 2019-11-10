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
    when :benchmark, :benchmark_electric_only_£, :benchmark_gas_only_£, :benchmark_storage_heater_only_£
      BenchmarkComparisonAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :benchmark_kwh, :benchmark_kwh_electric_only
      BenchmarkComparisonAdviceSolarSchools.new(school, chart_definition, chart_data, chart_symbol)
    when :thermostatic
      ThermostaticAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :cusum
      CusumAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_longterm_trend
      ElectricityLongTermTrend.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_longterm_trend
      GasLongTermTrend.new(school, chart_definition, chart_data, chart_symbol)
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
    when :last_2_weeks_gas
      Last2WeeksDailyGasTemperatureAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :last_2_weeks_gas_degreedays
      Last2WeeksDailyGasDegreeDaysAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :last_2_weeks_gas_comparison_temperature_compensated
      Last2WeeksDailyGasComparisonTemperatureCompensatedAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :last_4_weeks_gas_temperature_compensated
      Last4WeeksDailyGasComparisonTemperatureCompensatedAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :last_7_days_intraday_gas
      Last7DaysIntradayGas.new(school, chart_definition, chart_data, chart_symbol)
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
      res = DashboardEnergyAdvice.solar_pv_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol) if res.nil?
      res = DashboardEnergyAdvice.storage_heater_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol) if res.nil?
      res = DashboardEnergyAdvice.co2_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol) if res.nil?
      res = DashboardEnergyAdvice.financial_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol) if res.nil?
      res
    end
  end

  def generate_advice
    raise EnergySparksUnexpectedStateException.new('Error: unexpected call to DashboardChartAdviceBase abstract base class')
  end

protected

# copied from heating_regression_model_fitter.rb TODO(PH,17Feb2019) - merge
def html_table(header, rows, totals_row = nil)
  HtmlTableFormatting.new(header, rows, totals_row).html
=begin
  # TODO(PH, 9Oct2019) remove
  template = %{
    <p>
      <table class="table table-striped table-sm">
        <% if header %>
          <thead>
            <tr class="thead-dark">
              <% header.each do |header_titles| %>
                <th scope="col"> <%= header_titles.to_s %> </th>
              <% end %>
            </tr>
          </thead>
        <% end %>
        <tbody>
          <% rows.each do |row| %>
            <tr>
              <% row.each do |val| %>
                <td> <%= val %> </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
        <% if totals_row %>
          <tr class="table-success">
          <% totals_row.each do |total| %>
            <th scope="col"> <%= total.to_s %> </th>
          <% end %>
          </tr>
        <% end %>
      </table>
    </p>
  }.gsub(/^  /, '')

  generate_html(template, binding)
=end
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
    '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
  end
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
    "<p>#{equivalence_text} <button class=\"btn btn-secondary\" data-toggle=\"popover\" data-container=\"body\" data-placement=\"top\" data-title=\"How we calculate this\" data-content=\"#{calculation_text}\"> See how we calculate this</button></p>"
  end

  def random_equivalence_text(kwh, fuel_type)
    equiv_type, conversion_type = EnergyEquivalences.random_equivalence_type_and_via_type
    _val, equivalence, calc, in_text, out_text = EnergyEquivalences.convert(kwh, :kwh, fuel_type, equiv_type, equiv_type, conversion_type)
    equivalence_tool_tip_html(equivalence, in_text + out_text + calc)
  end

  def percent(value)
    (value * 100.0).round(0).to_s + '%'
  end

  def pounds_to_kwh(pounds, fuel_type_sym)
    pounds / ConvertKwh.scale_unit_from_kwh(:£, fuel_type_sym)
  end

  def pounds_to_pounds_and_kwh(pounds, fuel_type_sym)
    kwh = pounds_to_kwh(pounds, fuel_type_sym)
    kwh_text = FormatEnergyUnit.scale_num(kwh)
    '&pound;' + FormatEnergyUnit.scale_num(pounds) + ' (' + kwh_text + 'kWh)'
  end

  def kwh_to_pounds_and_kwh(kwh, fuel_type_sym, data_units = @chart_definition[:yaxis_units])
    pounds = YAxisScaling.convert(data_units, :£, fuel_type_sym, kwh, false)
    # logger.info "kwh_to_pounds_and_kwh:  kwh = #{kwh} £ = #{pounds}"
    '&pound;' + FormatEnergyUnit.scale_num(pounds) + ' (' + FormatEnergyUnit.scale_num(kwh) + 'kWh)'
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
              <td class="text-right"><%= YAxisScaling.convert(units, :kwh, fuel_type, val) %></td>
              <% if row.match(/export/i) %>
                <td class="text-right"><%= YAxisScaling.convert(units, :£, :solar_export, val) %></td>
              <% else %>
                <td class="text-right"><%= YAxisScaling.convert(units, :£, fuel_type, val) %></td>
              <% end %>
              <td class="text-right"><%= YAxisScaling.convert(units, :co2, fuel_type, val) %></td>
              <td class="text-right"><%= percent(pct) %></td>
            </tr>
          <% end %>

          <% if totals_row %>
            <tr class="table-success">
              <td><b>Total</b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :kwh, fuel_type, total) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :£, fuel_type, total) %></b></td>
              <td class="text-right table-success"><b><%= YAxisScaling.convert(units, :co2, fuel_type, total) %></b></td>
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

class HeatingAnalysisBase < DashboardChartAdviceBase
  include Logging

  attr_reader :heating_model

  def initialize(school, chart_definition, chart_data, chart_symbol, meter_type = :aggregated_heat)
    super(school, chart_definition, chart_data, chart_symbol)
    @meter_type = meter_type
    @heating_model = calculate_model
  end

  def heat_meter
    @meter_type == :aggregated_heat ? @school.aggregated_heat_meters : (@school.storage_heater_meter.nil? ? nil : @school.storage_heater_meter)
  end

  def a
    heating_model.average_heating_school_day_a
  end

  def b
    heating_model.average_heating_school_day_b
  end

  def r2
    heating_model.average_heating_school_day_r2
  end

  def r2_rating_adjective
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_adjective(r2)
  end

  def base_temperature
    heating_model.average_base_temperature
  end

  def predicted_kwh(temperature)
    a + b * temperature
  end

  def insulation_hotwater_heat_loss_estimate
    loss_kwh, percent_loss = heating_model.hot_water_poor_insulation_cost_kwh(one_year_before_last_meter_date, last_meter_date)
    loss_kwh
  end

  def last_meter_date
    heat_meter.amr_data.end_date
  end

  def one_year_before_last_meter_date
    start_date = [last_meter_date - 364, heat_meter.amr_data.end_date].min
  end

  def calculate_model
    period = SchoolDatePeriod.new(:analysis, 'Current Year', one_year_before_last_meter_date, last_meter_date)
    heat_meter.model_cache.create_and_fit_model(:best, period)
  end
end

#==============================================================================
class BenchmarkComparisonAdvice < DashboardChartAdviceBase
  include Logging

  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  protected def electric_usage
    get_energy_usage('electricity', :electricity, index_of_most_recent_date)
  end

  protected def gas_usage
    get_energy_usage('gas', :gas, index_of_most_recent_date)
  end

  protected def gas?;             !gas_usage.nil?             end
  protected def electricity?;     !electric_usage.nil?        end
  protected def storage_heaters?; !storage_heater_usage.nil?  end

  protected def storage_heater_usage
    get_energy_usage('storage heaters', :electricity, index_of_most_recent_date)
  end

  protected def electric_comparison_regional
    compare = comparison('electricity', index_of_data('Regional Average'))
    generate_html(%{ The electricity usage <%= compare %>: }.gsub(/^  /, ''), binding)
  end

  protected def gas_comparison_regional
    compare = comparison('gas', index_of_data('Regional Average'))
    generate_html(%{ The gas usage <%= compare %>: }.gsub(/^  /, ''), binding)
  end

  protected def storage_heater_comparison_regional
    compare = comparison('storage heaters', index_of_data('Regional Average'))
    generate_html(%{ The storage heater usage <%= compare %>: }.gsub(/^  /, ''), binding)
  end

  protected def usage_adjective
    'spent'
  end

  protected def usage_preposition
    'on'
  end

  def generate_advice
    logger.info @school.name

    address = [@school.address, @school.postcode].uniq.compact.join(' ')

    header_template = %{
      <%= @body_start %>
      <% if @add_extra_markup %>
        <h1>Energy Dashboard for <%= @school.name %></title></h1>
        <body>
      <% end %>
      <p>
        <%= @school.name %> is a <%= @school.school_type %> school near <%= address %>
        with <%= @school.number_of_pupils %> pupils
        and a floor area of <%= @school.floor_area.round(0) %>m<sup>2</sup>.
      </p>
      <p>
        <% if actual_gas_usage > 0 && actual_electricity_usage <= 0 %>
          <%= energy_usage_intro('gas', gas_usage) %>
          <%= gas_comparison_regional %>
        <% elsif actual_electricity_usage > 0 && actual_gas_usage <= 0 && actual_storage_heater_usage <= 0 %>
          <%= energy_usage_intro('electricity', electric_usage) %>
          <%= electric_comparison_regional %>
        <% elsif actual_electricity_usage > 0 && actual_storage_heater_usage > 0 %>
          <%= energy_usage_intro('storage heating', storage_heater_usage, ',') %>
          plus <%= electric_usage %> for the remaining electrical appliances (lighting. ICT etc.).
          <%= electric_comparison_regional %>
          <%= storage_heater_comparison_regional %>
        <% elsif actual_storage_heater_usage > 0 %>
          <%= energy_usage_intro('storage heating', storage_heater_usage, ',') %>
          <%= storage_heater_comparison_regional %>
        <% else %>
          Your school <%= usage_adjective %> <%= electric_usage %> <%= usage_preposition %> electricity
          and <%= gas_usage %> <%= usage_preposition %> gas last year.
          <%= electric_comparison_regional %>
          <%= gas_comparison_regional %>
        <% end %>
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
            although good, could be improved
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
            although good, could be improved
          <% else %>
            is above average, the school should aim to reduce this,
          <% end %>
          which would save you <%= pound_electricity_saving_versus_exemplar %> per year if you matched the most energy efficient (exemplar) schools.
          <% random_equivalence_text(kwh_electricity_saving_versus_exemplar, :electricity) %>
        <% end %>
      <% end %>
      </p>
      <% if actual_gas_usage > 0 %>
        <p>
          <% if percent_gas_of_regional_average < 0.7 %>
            Well done you gas usage is very low and you should be congratulated for being an energy efficient school.
          <% elsif percent_gas_of_regional_average < 0.7 && percent_electricity_of_regional_average < 0.7 %>
            Well done you energy usage is very low and you should be congratulated for being an energy efficient school.
          <% else %>
            Whether you have old or new school buildings, good energy management and best
            practice in operation can save significant amounts of energy. With good management
            an old building can use significantly less energy than a poorly managed new building.
            Improving controls, upgrading to more efficient lighting and other measures are
            applicable to all school buildings.
          <% end %>
        </p>
      <% end %>
      <% if actual_storage_heater_usage > 0 %>
        <p>
          Energy Sparks has taken the meter readings from your electricity meter and split it into two:
          electricity used by your storage heaters and the remainder. This allows you to better understand
          how much electricity is used for heating via storage heaters which vary significantly with outside
          temperatures and the remainder (all other appliances including lighting and ICT) which is less seasonal.
        </p>
      <% end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end

  def energy_usage_intro(fuel, usage, sentence_end = '.')
    text = %{
      Your school <%= usage_adjective %> <%= usage %> <%= usage_preposition %> <%= fuel %> last year<%= sentence_end %>
    }
    generate_html(text.gsub(/^  /, ''), binding)
  end

  def actual_electricity_usage
    actual_fuel_usage('electricity', index_of_most_recent_date)
  end

  def actual_gas_usage
    actual_fuel_usage('gas', index_of_most_recent_date)
  end

  def actual_storage_heater_usage
    actual_fuel_usage('storage heaters', index_of_most_recent_date)
  end

  def actual_fuel_usage(fuel, index)
    return 0.0 unless @chart_data[:x_data].key?(fuel)
    @chart_data[:x_data][fuel][index]
  end

  def average_regional_electricity_usage
    actual_fuel_usage('electricity', index_of_data('Regional Average'))
  end

  def average_regional_gas_usage
    actual_fuel_usage('gas', index_of_data('Regional Average'))
  end

  def exemplar_electricity_usage
    actual_fuel_usage('electricity', index_of_data('Exemplar School'))
  end

  def exemplar_gas_usage
    actual_fuel_usage('gas', index_of_data('Exemplar School'))
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

  def kwh_electricity_saving_versus_exemplar
    pounds_to_kwh(actual_electricity_usage - exemplar_electricity_usage, :electricity)
  end

  def comparison(type_str, with)
    usage_from_chart_£ = @chart_data[:x_data][type_str][index_of_most_recent_date]
    benchmark_from_chart = @chart_data[:x_data][type_str][with]
    formatted_usage_£ = FormatEnergyUnit.format(:£, usage_from_chart_£, :html)
    benchmark_usage_£ = FormatEnergyUnit.format(:£, benchmark_from_chart, :html)

    if formatted_usage_£ == benchmark_usage_£ # values same in formatted space
      'is similar to regional schools which spent ' + benchmark_usage_£
    elsif usage_from_chart_£ > benchmark_from_chart
      'is more than similar regional schools which spent ' + benchmark_usage_£
    else
      'is less than similar regional schools which spent ' + benchmark_usage_£
    end
  end

  def get_energy_usage(type_str, type_sym, index)
    return nil unless @chart_data[:x_data].key?(type_str) && @chart_data[:x_data][type_str].sum > 0.0
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
class BenchmarkComparisonAdviceSolarSchools < BenchmarkComparisonAdvice
  protected def usage_adjective
    'consumed'
  end

  protected def usage_preposition
    'of'
  end

  # this is a bit of a bodge, for solar schools we just want to talk about kWh
  # and the spend information requires detailed tariff data
  # the charts are also in kWh and not pounds so override parent's £ conversion
  def pounds_to_pounds_and_kwh(kwh, _fuel_type_sym)
    kwh_text = FormatEnergyUnit.scale_num(kwh)
    kwh_text + 'kWh'
  end

  # as above just do in kWh
  def pound_gas_saving_versus_exemplar
    pounds = actual_gas_usage - exemplar_gas_usage
    kwh = pounds_to_kwh(pounds, :gas)
    FormatEnergyUnit.scale_num(kwh) + 'kWh'
  end

  # as above just do in kWh
  def pound_electricity_saving_versus_exemplar
    pounds = actual_electricity_usage - exemplar_electricity_usage
    kwh = pounds_to_kwh(pounds, :electricity)
    FormatEnergyUnit.scale_num(kwh) + 'kWh'
  end

  def comparison(type_str, type_sym, with)
    usage_from_chart_kwh = @chart_data[:x_data][type_str][index_of_most_recent_date]
    benchmark_from_chart = @chart_data[:x_data][type_str][with]
    formatted_usage_kwh = FormatEnergyUnit.format(:kwh, usage_from_chart_kwh, :html)
    benchmark_usage_kwh = FormatEnergyUnit.format(:kwh, benchmark_from_chart, :html)

    if formatted_usage_kwh == benchmark_usage_kwh # values same in formatted space
      'is similar to regional schools which spent ' + benchmark_usage_kwh
    elsif usage_from_chart_kwh > benchmark_from_chart
      'is more than similar regional schools which consumed ' + benchmark_usage_kwh
    else
      'is less than similar regional schools which consumed ' + benchmark_usage_kwh
    end
  end

end
#==============================================================================
class FuelDaytypeAdvice < DashboardChartAdviceBase
  attr_reader :fuel_type, :fuel_type_str
  BENCHMARK_PERCENT = 0.5
  def initialize(school, chart_definition, chart_data, chart_symbol, fuel_type, exemplar_percentage)
    super(school, chart_definition, chart_data, chart_symbol)
    @fuel_type = fuel_type
    @fuel_type_str = @fuel_type.to_s
    @exemplar_percentage = exemplar_percentage
  end

  def generate_advice
    in_hours, out_of_hours = in_out_of_hours_consumption(@chart_data)
    percent_value = out_of_hours / (in_hours + out_of_hours)
    percent_str = percent(percent_value)
    saving_percent = percent_value - @exemplar_percentage
    saving = (in_hours + out_of_hours) * saving_percent
    saving_kwh = ConvertKwh.convert(@chart_definition[:yaxis_units], :kwh, @fuel_type, saving)
    saving_£ = ConvertKwh.convert(@chart_definition[:yaxis_units], :£, @fuel_type, saving)

    excluding_storage_heaters = (@school.storage_heaters? && fuel_type_str == 'electricity') ? '(excluding storage heaters)' : ''

    table_info = html_table_from_graph_data(@chart_data[:x_data], @fuel_type, true, 'Time Of Day')

    header_template = %{
      <%= @body_start %>
        <p>
          This chart shows when you have used <%= @fuel_type_str %> <%= excluding_storage_heaters %> over the past year.
          <%= percent(percent_value) %> of your <%= @fuel_type_str %> usage is out of hours:
          which is <%= adjective(percent_value, BENCHMARK_PERCENT) %>
          of <%= percent(BENCHMARK_PERCENT) %>.
          <% if percent_value > @exemplar_percentage %>
            The best schools only consume <%= percent(@exemplar_percentage) %> out of hours.
            Reducing your school's out of hours usage to <%= percent(@exemplar_percentage) %>
            would save <%= pounds_to_pounds_and_kwh(saving_£, @fuel_type) %> per year.
            <%# increase loop size to test %>
            <% 1.times do |_i| %>
              <%= random_equivalence_text(saving_kwh, @fuel_type) %>
            <% end %>
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
        This the breakdown for the most recent year:
      </p>
      <p>
      <%= table_info %>
      </p>
      <% if @school.storage_heaters? %>
        <p>
          The remaining charts on this page analyse just your non-storage heater electricity consumption.
        </p>
      <% end %>
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
    in_hours = 0.0
    out_of_hours = 0.0
    breakdown[:x_data].each do |daytype, consumption|
      if daytype == SeriesNames::SCHOOLDAYOPEN
        in_hours += consumption[0]
      else
        out_of_hours += consumption[0]
      end
    end
    [in_hours, out_of_hours]
  end
end

#==============================================================================
class ElectricityDaytypeAdvice < FuelDaytypeAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :electricity, 0.35)
  end
end
#==============================================================================
class GasDaytypeAdvice < FuelDaytypeAdvice
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol, :gas, 0.3)
  end
end
#==============================================================================
class GasLongTermTrend < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart shows your gas usage over the last few years, and how it has changed.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          Reducing gas consumption can be achieved by turning your school's thermostat down,
          and by reducing out of hours usage.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class ElectricityLongTermTrend < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart shows your electricity usage over the last few years, and how it has changed.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          Unless the school has had additional buildings added, if you are managing your electricity
          consumption well this should show a downward trend; more modern ICT equipment,
          LED lighting and behavioural change all contribute to reducing electricity usage.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
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
        This graph shows the same information as the graph above but over a longer period of time.
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
        This graph shows how the gas consumption of the school varies on school days when the heating is on in the winter (aggregated across the whole year):
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
        <h2>How your <%= @fuel_type_str %> varies throughout the year</h2>
        <p>
          The graph below shows how your <%= @fuel_type_str %> consumption varies throughout the year.
          Each bar represents a whole week and the split between holiday, weekend and school day open and closed consumption for that week.
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
class ThermostaticAdvice < HeatingAnalysisBase
  include Logging

  def initialize(school, chart_definition, chart_data, chart_symbol, meter_type = :aggregated_heat)
    super(school, chart_definition, chart_data, chart_symbol, meter_type)
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
            The x axis the outside temperature. This is inverse of temperature,
            the higher the degree days the colder the temperature.
          </p>
          <p>
            If the heating has good thermostatic control then the points at the top of
            chart when the heating is on and the school occupied should be close to the trend line (red squares).
            This is because the amount of heating required on a single day is linearly proportional to
            the difference between the inside and outside temperature, and any variation from the
            trend line would suggest thermostatic control isn't working too well.
          </p>
          <p>
            Two sets of data are provided on the chart. The points associated with the group at the top of
            the chart are those for winter school day heating. As it gets warmer the daily gas consumption drops.
          </p>
          <p>
            The second set of data at the bottom of the chart is for gas consumption in the summer when the
            heating is not on; typically this is from hot water and kitchen consumption. The slope of this line
            is often an indicaton of how well insulated the hot water system is; of the consumption increases
            as it gets colder it suggests a lack of insulation. An estimate of this loss across the last
            year is <%= kwh_to_pounds_and_kwh(insulation_hotwater_heat_loss_estimate, :gas)  %>.
          </p>
          <p>
            The outside temperature at which the two trendlines cross is generally a good indication
            of the schools 'balance point temperature', this is the outside temperature where there are enough
            internal gains to offset heating losses i.e. below this temperature the heating should be
            turned on to maintain the internal temperature.
            A value below 18C is generally good. A value above this might indicate either the school
            is very poorly insulated, or more likely the internal temperature settings may be too high.
          </p>

      <% if @add_extra_markup %>
          </body>
      <% end %>
      </html>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

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
          Your school's r2 of <%= r2.round(2) %> is <%= r2_rating_adjective %>.
        </p>
        <p>
          For energy experts, the formula which defines the trend line is very interesting.
          It predicts how the gas consumption varies with outside temperature.
        </p>
        <p>In the example above the formula is:</p>

        <blockquote>predicted_heating_requirement = <%= a.round(0) %> + <%= b.round(1) %> * outside temperature</blockquote>

        <p>Outside temperature is calculated as follows</p>

        <blockquote>temperature = min(<%= base_temperature.round(1) %>, the days average temperature)</blockquote>
        <p>
          So for your school if the average outside temperature is 12C
          the predicted gas consumption for the school would be
          <%= a.round(0) %> + <%= b.round(1) %> * 12.0  = <%= predicted_kwh(12.0).round(0) %> kWh for the day. Where as if the outside
          temperature was colder at 4C the gas consumption would be
          <%= a.round(0) %> + <%= b.round(1) %> * 4.0  = <%= predicted_kwh(4.0).round(0) %> kWh. See if you can read these values
          off the trend line of the graph above (degree days on the x axis and the answer -
          the predicted daily gas consumption on the y-axis).
        </p>
        <p>
            The values for the trend line and the text above will vary slightly as the model used in the text
            is more complicated than the one used by the chart, and if expressed in the chart would make it
            more difficult to read.
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

    footer_template = %{
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
        <h2> Your <%= @fuel_type_str %> usage by day of the week </h2>
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
    alert.analyse(@school.aggregated_electricity_meters.amr_data.end_date)
    # :avg_baseload, :benchmark_per_pupil, :benchmark_per_floor_area
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
      <p><%= alert.dashboard_summary %> </p>
      <p><%= alert.dashboard_detail %> </p>
      <p>
        Reducing a school's baseload is often the fastest way of reducing a school's energy costs
        and reducing its carbon footprint. For each 1kW reduction in baseload, the school will save
        £1,050 per year, and reduce its carbon footprint by 2,400 kg.
      </p>
      <p>
        Look carefully at the graph above, how has the baseload changed over time?
        Does it change seasonally (from summer to winter)? There should be very
        little difference between summer and winter electricity baseload, unless
        there is something not working properly at the school, for example
        electrical heating left on accidentally?
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
      This graph compares the average electricity consumption
      at the school during the last 2 years <%= @period %>.
      <% if type == :school_days %>
      It shows the peak electricity usage at the school (normally during
        the middle of the day) and the overnight electricity consumption.
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
      The graph below shows how the electricity consumption varies
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
        The 3 graphs below which are for the coldest weekends of recent years, attempt to demonstrate whether
        </p>
        <ol type="a">
        <li>Frost protection is configured for your school and</li>
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
    if @school.aggregated_heat_meters.heating_only?
      no_hotwater_advice
      return
    end

    advice = HotWaterInvestmentAnalysisText.new(@school)

    header_template = %{
      <%= @body_start %>
        <% if @chart_type == :hotwater %>
          <%= advice.introductory_hot_water_text_1 %>
          <%= advice.introductory_hot_water_text_2_with_efficiency_estimate %>
          <%= advice.introductory_hot_water_text_3_circulatory_inefficiency %>
          <%= advice.introductory_hot_water_text_4_analysis_intro %>
          <%= advice.estimate_of_boiler_efficiency_header %>
          <%= advice.estimate_of_boiler_efficiency_text_1_chart_explanation %> 
        <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <% if @chart_type == :hotwater %>
          <%= advice.estimate_of_boiler_efficiency_text_2_summary_table_info %>
          <%= advice.daytype_breakdown_table(:html) %>
          <%= advice.estimate_heat_required_text_header %>
          <%= advice.estimate_heat_required_text_1_calculation %>
          <%= advice.estimate_heat_required_text_2_comparison %>
          <%= advice.investment_choice_header %>
          <%= advice.investment_choice_text_1_2_choices %>
          <%= advice.investment_choice_text_2_table_intro %>
          <%= advice.investment_table(:html) %>
          <%= advice.investment_choice_text_3_accuracy_caveat %>
          <%= advice.investment_choice_text_4_improved_boiler_control_benefit %>
          <%= advice.investment_choice_text_5_point_of_use_electric_benefit %>
        <% end %>
      <%= @body_end %>
    }.gsub(/^  /, '')
    # <%= advice.investment_choice_text_5_further_guidance %>
    @footer_advice = generate_html(footer_template, binding)
  end

  def no_hotwater_advice
    header_template = %{
      <%= @body_start %>
        <p>
          <strong>This school appears to not use gas for hot water, so no advice is provided.</strong>
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    @footer_advice = nil_advice
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
#==============================================================================
class Last2WeeksDailyGasTemperatureAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          The remainder of the charts on this page are designed to allow you to see
          the detail of your recent gas consumption. This is particularly useful if
          you are trying to make improvements in the control of your boiler to save energy.
        </p>
        <p>
          This first chart shows the daily gas consumption over the last 2 weeks
          including the outside temperature:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <p>
        Typically, your gas consumption should vary with outside temperature,
        the colder it is the more gas you will consume, for example normally
        twice as much gas might be consumed if the outside temperature is 0C,
        versus 10C. So, sometimes it can be difficult to see from this chart
        whether changes you have been making to the boiler have made a difference
        because outside temperature might be a more dominant effect. The next two
        charts try to isolate the effect of outside temperature
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class Last2WeeksDailyGasDegreeDaysAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart is identical to the previous chart but replaces temperature
          with degree days. Degree days &hyphen; how cold it is, increases as it gets colder
          and makes it easier to see gas consumption increasing with coldness
          (an explanation of degree days appears above under &apos;By Week: Gas&apos;).
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          You should be able to see the gas consumption increasing and decreasing
          with degree days. Any change from this tracking (correlation) might be
          the impact of recent changes being made to boiler control, or because you
          have poor thermostatic control in your school. This means your heating controls
          are not adjusting the boiler in response to changes in temperature.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class Last2WeeksDailyGasComparisonTemperatureCompensatedAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart automatically adjusts the school’s gas consumption for outside temperature,
          removing the effect of changes in outside temperature. This should make it easier to
          see the impact of changes you might be making in boiler control:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          The quality of the adjustment for outside temperatures may not be perfect as it
          is dependent on the quality of the school&apos;s thermostatic control (see the thermostatic
          chart on the Advanced Boiler Control page for an explanation). But, it should give you
          a much better idea if you are making progress with reducing gas consumption, and the
          long&hyphen;term impact of any changes you might have made? For example, a reduction on the
          chart from one week to the next of 10&percnt; might indicate a long&hyphen;term annual reduction of
          10% in your heating costs.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class Last4WeeksDailyGasComparisonTemperatureCompensatedAdvice < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart is temperature compensated as per the chart above, but shows a
          longer&hyphen;term view of any changes in the school’s gas consumption:
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
#==============================================================================
class Last7DaysIntradayGas < DashboardChartAdviceBase
  def initialize(school, chart_definition, chart_data, chart_symbol)
    super(school, chart_definition, chart_data, chart_symbol)
  end

  def generate_advice
    header_template = %{
      <%= @body_start %>
        <p>
          This chart allows you to see when your boiler has been turning on and off
          over the last week and how much power (gas)
          it has been consuming in &apos;kilowatts&apos; (kW):
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @header_advice = generate_html(header_template, binding)

    footer_template = %{
      <%= @body_start %>
        <p>
          By clicking the legend at the bottom of the chart, you can turn the lines
          on the chart on and off for individual days &hyphen; making it easier to understand
          what is going on at the school.
        </p>
        <p>
          In a school with a heating system that is working well (good boiler, good pipework
          for heat distribution, large enough radiators, and reasonable insulation),
          you might expect the heating to turn on at about 6am, and peak for the next
          2 hours while the school is being heated up, and then gradually reduce during the day.
          In most schools the heat generated by electrical equipment and 30 pupils in a class room
          would suggest classrooms need very little additional heating from the school&apos;s boiler,
          once the pupils arrive.
        </p>
        <p>
          If the boiler has &apos;optimal start control&apos; configured, you might notice the start time of
          the boiler changing automatically &hyphen; from perhaps 6:30am in milder weather to earlier
          e.g. 4:30pm in colder weather. In very cold weather you might notice the heating coming on &apos;at random&apos;
          – this is most likely frost protection &hyphen; the boiler turning the heating system on to stop
          the school&apos;s pipework freezing.
        </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    @footer_advice = generate_html(footer_template, binding)
  end
end
