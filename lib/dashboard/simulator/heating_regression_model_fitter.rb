require 'erb'
# Runs heating regression model parameter fitting and temperature balance point optimisation
class HeatingRegressionModelFitter
  include Logging

  attr_reader :meter_collection, :doc
  def initialize(meter_collection)
    @meter_collection = meter_collection
    @doc = MultiMediaPage.new
    @chart_manager = ChartManager.new(@meter_collection)
    @add_extra_markup = ENV['School Dashboard Advice'] == 'Include Header and Body'
    if @add_extra_markup
      @body_start = '<html><head>'
      @body_end = '</head></html>'
    else
      @body_start = ''
      @body_end = ''
    end
  end

  def fit
    bm = Benchmark.measure {
      html summary_of_meters
      chart standard_chart(:group_by_year_gas_unlimited_meter_breakdown_heating_model_fitter)
      chart standard_chart(:meter_breakdown_pie_1_year)
      analyse_meters
    }
    puts doc
    puts bm.to_s
    @doc
  end

  private

  # build up a list of mixed html and charts for later display
  # if html  and last entry append
  def add_doc(type, content)
    if !doc.empty? && type == :html && doc.last.type == :html
      doc.last.content += content
    else
      doc.push(MultiMediaDetail.new(type, content))
    end
  end

  def html(content)
    add_doc(:html, content)
  end

  def chart(content)
    add_doc(:chart, content)
  end

  def analyse_meters
    @meter_collection.heat_meters.each do |meter|
      html horizontal_line
      html meter_title(meter)

      meter_function = MeterAttributes.attributes(meter, :function)

      if !meter_function.nil? && meter_function.include?(:hotwater_only)
        document_hotwater_only(meter)
      elsif  !meter_function.nil? && meter_function.include?(:kitchen_only)
        document_kitchen_only(meter)
      else
        analyse_optimal_heating_regression_model(meter)
      end
    end

    if @meter_collection.heat_meters.length > 1
      combined_meter = @meter_collection.aggregated_heat_meters
      html horizontal_line
      html meter_title(combined_meter)
      analyse_optimal_heating_regression_model(combined_meter)
    end
  end

  def analyse_optimal_heating_regression_model(meter)
    html header(3, 'Determing optimal regression model for this heating meter')
    html paragraph('First we analyse whether there is a gradual reduction in consumption by day of the week:')
    chart_results = run_standard_chart_with_for_one_meter(:gas_by_day_of_week, meter, @meter_collection.heat_meters.length)
    chart chart_results
    doy_text = 'If there is a signifcant reduction between days we assume the meter monitors a heating system '\
              'in a building with signifcant thermal mass and reasonable admittance, where you would expect a '\
              'gradual reduction in gas consumption as the building warms up during the week, following '\
              'weekends when the building shouldnt be heated.'
    html paragraph(doy_text)
    num_declining_days = analyse_chart_by_day_of_week_breakdown(chart_results)
    html paragraph('The chart shows ' + num_declining_days.to_s + ' days of declining gas consumption during the week')
    if num_declining_days > 1
      run_temperature_balance_point_fit_on_heavy_thermal_mass_model(meter, num_declining_days)
    else
      run_temperature_balance_point_fit_on_simple_model(meter)
    end
  end

  def meter_title(meter)
    template = %{ 
      <%= @body_start %>
      <h2>Analysing meter <%= meter.name %> (<%= meter.mpan_mprn.to_s %>)</h2>
      <%= @body_end %>
    }.gsub(/^  /, '')
    generate_html(template, binding)
  end

  def paragraph(text)
    html_section('<p>', text, '</p>')
  end

  def header(level, text)
    start_header = '<h' + level.to_s + '>'
    end_header = '</h' + level.to_s + '>'
    html_section(start_header, text, end_header)
  end

  def html_section(start_tag, text, end_tag)
    template = %{ 
      <%= @body_start %>
      <%= start_tag %><%= text %><%= end_tag %>
      <%= @body_end %>
    }.gsub(/^  /, '')
    generate_html(template, binding)
  end

  def document_hotwater_only(meter)
    html paragraph('This meter is used for hot water only. Please check that this appears to be the case by looking at these charts:')
    chart run_standard_chart_with_for_one_meter(:gas_by_day_of_week, meter)
    chart run_standard_chart_with_for_one_meter(:gas_by_day_of_week, meter, meter_collection.heat_meters.length)
    html paragraph('There should be little difference between the days of the week and summer and winter usage')
  end

  def document_kitchen_only(meter)
    html paragraph('This meter is used for the kitchen only. Please check that this appears to be the case by looking at these 3 charts:')
    chart run_standard_chart_with_for_one_meter(:gas_intraday_schoolday_last_year, meter, meter_collection.heat_meters.length)
    chart run_standard_chart_with_for_one_meter(:group_by_week_gas, meter, meter_collection.heat_meters.length)
    chart run_standard_chart_with_for_one_meter(:gas_by_day_of_week, meter, meter_collection.heat_meters.length)
    advice_text = 'Check the charts are consistent with a kitchen profile '\
                  'morning only usage, not holidays, little difference between weekdays '\
                  'and not much difference between winter and summer'
    html paragraph(advice_text)
  end

  def run_standard_chart_with_for_one_meter(chart_name, meter, number_of_meters = 1)
    chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name].deep_dup
    chart_config[:meter_definition] = meter.id if number_of_meters > 1
    chart_config[:name] += + ' ' + meter.name + ' ' + meter.mpan_mprn.to_s
    chart_results = @chart_manager.run_chart(chart_config, (chart_name.to_s + '_cloned').to_sym)
    chart_results
  end

  def standard_chart(chart_name)
    chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name].deep_dup
    chart_results = @chart_manager.run_chart(chart_config, chart_name)
    puts chart_results
    chart_results
  end

  def summary_of_meters
    template = %{
      <%= @body_start %>
      <h1>Heating regression model analysis for <%= meter_collection.name %></h1>
      <p>
        <%= meter_collection.name %> 
        <% if meter_collection.heat_meters.length == 1 %>
          has 1 gas meter which has consumed the following over the last few years:
        <% else %>
          has <%= meter_collection.heat_meters.length %> gas meters which have
          consumed the following over the last few years:
        <% end %>
      </p>
      <%= @body_end %>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end

  def horizontal_line
    template = %{ 
      <%= @body_start %>
      <hr>
      <%= @body_end %>
    }.gsub(/^  /, '')
    generate_html(template, binding)
  end

  def analyse_chart_by_day_of_week_breakdown(chart_results)
    day_of_week_number = 0
    meter_percents_by_day_of_week = []
    school_open_total_kwh = chart_results[:x_data]['School Day Open'].inject(:+)
    chart_results[:x_axis].each do |day_of_week|
      school_open_kwh = chart_results[:x_data]['School Day Open'][day_of_week_number]
      percent = school_open_kwh / school_open_total_kwh
      logger.info sprintf('    %-10.10s %10.0f kWh %2.1f percent', day_of_week, school_open_kwh, 100.0 * percent)
      meter_percents_by_day_of_week.push(percent) if day_of_week_number >= 1 && day_of_week_number <= 5
      day_of_week_number += 1
    end

    declining_days_kwh = 0
    (0...(meter_percents_by_day_of_week.length - 1)).each do |doy_num|
      if (meter_percents_by_day_of_week[doy_num] - meter_percents_by_day_of_week[doy_num+1]) > 0.003
        declining_days_kwh += 1
      else
        break
      end
    end
    puts "Num days of declining consumption #{declining_days_kwh}" # note output in range 0 to 4
    declining_days_kwh
  end

  def run_temperature_balance_point_fit_on_simple_model(meter)
    html paragraph('Two charts:')
    html paragraph('The first is an intraday profile - does this look reasonable for heating?')
    chart run_standard_chart_with_for_one_meter(:gas_intraday_schoolday_last_year, meter, meter_collection.heat_meters.length)
    advice_text = 'The second is a break down by day of the week, we are running a simple regression model '\
                  'which ideally should only be used if the school doesnt have too much thermal mass '\
                  'and therefore the gas consumption should not reduce that much during the week:'
    html paragraph(advice_text)
    chart run_standard_chart_with_for_one_meter(:group_by_week_gas, meter, meter_collection.heat_meters.length)

    heat_amr_data = meter.amr_data
    start_date = heat_amr_data.start_date
    end_date = heat_amr_data.end_date
    period = SchoolDatePeriod.new(:fitting, 'Meter Period', start_date, end_date)

    puts "-" * 90
    puts "calculating simple model for #{meter.name}"
    simple_model = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(heat_amr_data, @meter_collection.holidays, @meter_collection.temperatures)
 
    cusum_variances = []
    temperatures = []
    results = []

    for temperature in (8..30).step(1.0)
      simple_model.base_degreedays_temperature = temperature
      simple_model.calculate_regression_model(period)
      simple_model.calculate_heating_periods(start_date, end_date, false)

      r2 = simple_model.models[:heating_occupied].r2
      a = simple_model.models[:heating_occupied].a
      b = simple_model.models[:heating_occupied].b
      bt = simple_model.models[:heating_occupied].base_temperature
      h_way = simple_model.halfway_kwh.round(0)
      hd = simple_model.heating_on_days.to_i
      sd, mean = simple_model.cusum_standard_deviation_average
      
      if sd.nan? || mean.nan?
        puts "simple: t = #{temperature} NaN"
      else
        temperatures.push(temperature)
        cusum_variances.push(sd)
        results.push({ base_temperature: bt.round(1), cusum_variance: sd.round(0), mean_cusum: mean.round(0),
          a: a.round(2), b: b.round(2), r2: r2.round(3), heat_days: hd, halfway_kwh: h_way})
        logger.info "simple: t = #{bt.round(1)} sd = #{sd.round(0)} mean = #{mean.round(0)} a = #{a.round(2)} b = #{b.round(2)} r2 = #{r2.round(3)} heat days = #{hd} half way = #{h_way}"
      end

      simple_model.save_raw_data_to_csv_for_debug('regression model debug ' + meter.name + '.csv') if temperature == 18
    end

    html html_table(results)

    minimum_variance_index = cusum_variances.index(cusum_variances.min)
    optimum = results[minimum_variance_index]
    text = "Minimum variance occurs at a temperature of #{temperatures[minimum_variance_index]}."\
           "This indicates an optimal simple model of X = #{optimum[:a]} + #{optimum[:b]} * DD at base T #{optimum[:base_temperature]} "
    meter_attributes_entry_description(meter, :simple, optimum[:a], optimum[:b], optimum[:base_temperature])
    html paragraph(text)
    logger.info text
    @halfway_kwh
  end

  def meter_attributes_entry_description(meter, type, a, b, base_temperature)
    html paragraph('Please add the following configuration to the meter attributes table:')
    config = {
      meter.mpan_mprn => { 
        heating_model: { type: type, a: a, b: b, base_temperature: base_temperature }
      }
    }
    html paragraph(config.to_s)
    puts config.to_s
  end

  def html_table(results)
    template = %{
      <p>
        <table class="table table-striped table-sm">
          <thead>
            <tr class="thead-dark">
              <% results[0].keys.each do |header| %>
                <th scope="col"> <%= header.to_s %> </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <% results.each do |row| %>
              <tr>
                <% row.values.each do |val| %>
                  <td> <%= val %> </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </p>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end

  def run_temperature_balance_point_fit_on_heavy_thermal_mass_model(meter, num_decliding_days)
    run_temperature_balance_point_fit_on_simple_model(meter)
  end

  # borrowed from advice software, so erhaps should be morved to library?
  def generate_html(template, binding)
    begin
      rhtml = ERB.new(template)
      rhtml.result(binding)
    rescue StandardError => e
      logger.error "Error generating html for #{self.class.name}"
      logger.error e.message
      logger.error e.backtrace[0]
      '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
    end
  end

=begin
    puts "-" * 90
    puts "calculating heavy thermal mass model"
    thermal_mass_model = AnalyseHeatingAndHotWater::HeatingModelWithThermalMass.new(heat_amr_data, school.holidays, school.temperatures)
 
    for temperature in (8..30).step(0.5)
      thermal_mass_model.base_degreedays_temperature = temperature
      thermal_mass_model.calculate_regression_model(period)
      sd, mean = thermal_mass_model.cusum_standard_deviation_average
      if sd.nan? || mean.nan?
        puts "heavy: t = #{temperature} NaN"
      else
        puts "heavy: t = #{temperature} sd = #{sd.round(0)} mean = #{mean.round(0)}"
      end
    end
=end

end