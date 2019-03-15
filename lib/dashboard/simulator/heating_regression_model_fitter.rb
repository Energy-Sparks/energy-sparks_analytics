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
    @debug = true
  end

  def fit
    bm = Benchmark.measure {
      html summary_of_meters
      chart standard_chart(:group_by_year_gas_unlimited_meter_breakdown_heating_model_fitter)
      chart standard_chart(:meter_breakdown_pie_1_year)
      analyse_meters
    }
    # puts doc
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

      meter_function = meter.attributes(:function)

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
#   html_current_meter_attributes(meter)
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

  def horizontal_line(thickness = 20)
    template = %{
      <%= @body_start %>
      <hr size=<%= thickness %> noshade>
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

    period = meter_period(meter)

    puts "-" * 90
    puts "calculating simple model for #{meter.name}"
    simple_model = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(meter, @meter_collection.holidays, @meter_collection.temperatures)
    thermally_massive_model = AnalyseHeatingAndHotWater::HeatingModelWithThermalMass.new(meter, @meter_collection.holidays, @meter_collection.temperatures)

    temps = [8, 9, 10, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5, 16, 16.5, 17, 17.5, 18, 18.5, 19, 19.5, 20, 21, 22, 25, 30]
    delimination_methods = [
      # [:fixed_winter_months, nil, nil, 'Fixed winter months'],
      [:prediction_at_fixed_degreedays, nil, 'Minimum heating day set to predicted kWh at base temperature'],
      [:percent_regression_model_prediction, 0.5, 'Minimum heating day set to 50% of kWh predicted by model at T' ]
    ]

    unless meter.attributes(:heating_model).nil? || meter.attributes(:heating_model).dig(:heating_model, :heating_day_determination_method).nil?
      configuration = meter.attributes(:heating_model).dig(:heating_model, :heating_day_determination_method)
      delimination_methods.push([])
    end

    cusum_variances = []
    temperatures = []

    [simple_model, thermally_massive_model].each do |model|
      delimination_methods.each do |delimination_method, delimination_parameter, delimination_description|
        temps.each do |temperature|
          model.base_degreedays_temperature = temperature
          model.full_regression_model_calculation(period, temperature, delimination_method, delimination_parameter)

          sd, mean, actual, predicted, detail = model.cusum_standard_deviation_average

          html horizontal_line(5)
          html header(3, "#{model.name} Model at degree day base temperature of #{temperature}")
          html html_table(['type'] + detail[:summer_weekend].keys, hash_to_array_of_arrays(detail))

          if sd.nan? || mean.nan?
            puts "simple: t = #{temperature} NaN"
          else
            temperatures.push([temperature, model.name, delimination_description])
            cusum_variances.push(sd)
          end

          if @debug
            filename = debug_csv_filename(model.name, temperature, delimination_description)
            puts filename
            model.save_raw_data_to_csv_for_debug(filename)
          end
        end
      end
    end

    minimum_variance_index = cusum_variances.index(cusum_variances.min)
    temperature, model_name, delimination_description = temperatures[minimum_variance_index]

    text = "Minimum variance occurs at a temperature of #{temperature} and model type #{model_name} and heating day delimination method #{delimination_description}"
    html paragraph(text)
    logger.info text
  end

  def debug_csv_filename(model_name, base_temperature, delimination_description)
    # shorten name because of OneDrive 240char max filepath/name limit
    model_name = 'Massive Model' if model_name == 'Thermally Massive Heating Model'
    File.join(
      File.dirname(__FILE__), '../../../log/' + model_name +
      ' ' + base_temperature.to_s + ' ' + delimination_description + '.csv'
    )
  end

  def meter_period(meter)
    heat_amr_data = meter.amr_data
    start_date = heat_amr_data.start_date
    end_date = heat_amr_data.end_date
    SchoolDatePeriod.new(:fitting, 'Meter Period', start_date, end_date)
  end

  def array_of_hashs_to_array_of_hash_values(arr)
    rows = []
    arr.each do |hash|
      rows.push(hash.values)
    end
    rows
  end

  def hash_to_array_of_arrays(hash)
    rows = []
    hash.each do |hash, value|
      rows.push([hash] + value.values)
    end
    rows
  end

  def html_current_meter_attributes(meter)
    model_attributes = meter.attributes(:heating_model)
    html header(2, 'Existing heating model configuration')
    unless model_attributes.nil?
      html paragraph(date_key_description(model_attributes, :calculation_start_date, 'start'))
      html paragraph(date_key_description(model_attributes, :calculation_end_date, 'end'))
      html paragraph("Degree day base temperature is #{model_attributes[:regression_model][:degreeday_base_temperature]}C")
      regression_parameters = extract_regression_model_parameters_from_meter_configuration(model_attributes[:regression_model])
      html html_table(['day', 'Kwh per DD/day', 'Fixed kwh/day', 'r2'], regression_parameters)
      html paragraph("Heating day determination: #{model_attributes[:heating_day_determination]}")
      if model_attributes.key?(:hotwater_model)
        hw = model_attributes[:hotwater_model]
        html paragraph("Hot water model: #{hw[:kwh_per_degree_day_per_day]} kWh/dd/day + #{hw[:fixed_offset_kwh_per_day]} kWh/day")
      else
        html paragraph('No hot water model')
      end
    else
      html paragraph('Nothing currently configured for meter')
    end
  end

  def extract_regression_model_parameters_from_meter_configuration(config)
    filtered_parameters = %w[ monday tuesday wednesday thursday friday every_day ]
    config.select! { |k, _v| filtered_parameters.include?(k.to_s.downcase) }
    config.map { |k, v| [k.to_s] + v.values }
  end

  def date_key_description(hash, key, type)
    if hash.key?(key) && !hash[key].nil?
      "Fixed data #{type} date defined = #{hash[key]}"
    else
      "No fixed calculation #{type} date is defined"
    end
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

  def html_table(header, rows)
    template = %{
      <p>
        <table class="table table-striped table-sm">
          <thead>
            <tr class="thead-dark">
              <% header.each do |header_titles| %>
                <th scope="col"> <%= header_titles.to_s %> </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <% rows.each do |row| %>
              <tr>
                <% row.each do |val| %>
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
end