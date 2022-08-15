class AdviceBenchmark < AdviceBase
  MAXPERCENTVARAINCETOGENERATECHART = 0.05
  def alert_asof_date
    valid_meters.map { |meter| meter.amr_data.end_date }.min
  end

  protected def aggregate_meter
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.first
  end

  def valid_alert?
    super && days_all_meters_valid > 364
  end

  # partially override existing adaptation of old to new
  # advice chart and content
  # with specialised advice for schools with varying pupil numbers or floor area
  def chart_content(chart, charts_and_html)
    chart_name = chart[:config_name]

    if chart_name == normalised_benchmark_chart_name
      if worth_generating_normalised_chart?(chart_name)
        generate_normalised_chart_and_advice(chart_name, charts_and_html)
      end
    else
      super(chart, charts_and_html)
    end
  rescue => e
    puts e.message
    puts e.backtrace
  end

  def benchmark_chart_names
    :benchmark
  end

  def normalised_benchmark_chart_name
    :benchmark_varying_floor_area_pupils
  end

  private

  def valid_meters
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact
  end

  def days_all_meters_valid
    (first_end_date - last_start_date).to_i
  end

  def last_start_date
    valid_meters.map { |m| m.amr_data.start_date }.max
  end

  def first_end_date
    valid_meters.map { |m| m.amr_data.end_date   }.min
  end

  def worth_generating_normalised_chart?(chart_name)
    two_years_data? &&
      parameters_max_variance(chart_name).magnitude > MAXPERCENTVARAINCETOGENERATECHART
  end

  # approximation, may be a day out depending on how chart determines
  # start/end_dates but not an issue
  def two_years_data?
    years_all_meters_valid >= 2
  end

  def years_all_meters_valid
    (days_all_meters_valid / 364).round(0)
  end

  def large_enough_variance(chart_name)
    parameters_max_variance(parameters).magnitude > MAXPERCENTVARAINCETOGENERATECHART
  end

  def normalised_data_in_chart(chart_name)
    chart_config = ChartManager.new(@school).get_chart_config(chart_name)
    chart_config[:scale_y_axis].map { |config| config.keys.first }
  end

  def parameters_max_variance(chart_name)
    parameters = normalised_data_in_chart(chart_name)

    parameters.map do |parameter|
      vals = parameter_values(parameter)
      (vals.max - vals.min)/vals.max
    end.max
  end

  def parameter_values(parameter)
    case parameter
    when :number_of_pupils
      years_date_ranges.map { |date_range| @school.number_of_pupils(date_range.first, date_range.last) }
    when :floor_area
      years_date_ranges.map { |date_range| @school.floor_area(date_range.first, date_range.last) }
    end
  end

  # to an approximation compared with chart
  def years_date_ranges
    years_all_meters_valid.downto(0).map do |years_before|
      ed = first_end_date - years_before * 364
      sd = ed - 364 + 1
      sd..ed
    end
  end

  def generate_normalised_chart_and_advice(chart_name, charts_and_html)
    puts "Generating normaised advice for #{chart_name}"
    charts_and_html.push( { type: :html,       content: normalised_chart_explanation(chart_name) })
    charts_and_html.push( { type: :chart_name, content: chart_name } )
  end

  def normalised_chart_explanation(chart_name)
    text = %(
      <p>
        Perhaps a better way of comparing your school with
        benchmark and exemplar schools is to look at this
        chart which adjusts for changes in
        <%= varying_chart_parameters(chart_name) %> historically.
      </p>
    )

    ERB.new(text).result(binding)
  end

  def varying_chart_parameters(chart_name)
    parameters = normalised_data_in_chart(chart_name).map { |parameter| translate_parameter(parameter) }
    parameters.join(' and ')
  end

  def translate_parameter(parameter) # make translation easier
    case parameter
    when :floor_area
      'floor area'
    when :number_of_pupils
      'pupils'
    end
  end
end
