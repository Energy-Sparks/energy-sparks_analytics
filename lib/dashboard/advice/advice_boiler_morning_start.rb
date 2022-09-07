class AdviceGasBoilerMorningStart < AdviceBoilerHeatingBase

  def structured_content(user_type: nil)
    puts "Super content override confused"
    super(user_type: user_type)
  end

  def content(user_type: nil)
    charts_and_html = super(user_type: user_type)

    if self.class.analytics_user?(user_type)
      aggregate_html = aggregate_boiler_start_time_analysis_html(user_type)
      charts_and_html += aggregate_html unless aggregate_html.nil?
      charts_and_html.push( { type: :chart_name, content: :group_by_week_gas_versus_benchmark })
      charts_and_html.push( { type: :chart_name, content: :intraday_line_school_days_gas_reduced_data_versus_benchmarks })
    end

    charts_and_html
  end

  # component meter request (where multiple underlying heat meters)
  def boiler_start_time_analysis(config:, mpan_mprn:)
    boiler_start_time_analysis_html(mpan_mprn)
  end

  private

  def aggregate_boiler_start_time_analysis_html(user_type)
    mpxn = @school.aggregated_heat_meters.mpxn

    analysis_html = boiler_start_time_analysis_html(mpxn)

    return nil if analysis_html.nil?

    charts_and_html = []

    charts_and_html.push( { type: :html, content: '<h2>Aggregate meter analysis</h2>' } )
    charts_and_html += AdviceBase.meter_specific_chart_config(:boiler_start_time, mpxn)
    charts_and_html += AdviceBase.meter_specific_chart_config(:boiler_start_time_up_to_one_year, mpxn)
    charts_and_html += AdviceBase.meter_specific_chart_config(:boiler_start_time_up_to_one_year_no_frost, mpxn)
    charts_and_html.push( { type: :html, content: analysis_html } )

    remove_diagnostics_from_html(charts_and_html, user_type)
  end

  def boiler_start_time_analysis_html(mpxn)
    meter = @school.meter?(mpxn)

    [
      '<h3>Interpreted data</h3>',
      interpreted_table_html(meter),
      '<h3>Raw data</h3>',
      raw_analysis_table_html(meter)
    ].join
  rescue => e
    "<p> Boiler start time analysis failed #{e.message}</p>"
  end

  def raw_analysis_table_html(meter)
    analyser = BoilerStartAndEndTimeAnalysis.new(@school, meter)
    data = analyser.analyse

    row_config = [
      { name: 'Day type',                                                           unit: String  },
      { name: 'Regression start time',          key: :regression_start_time,        unit: Float   },
      { name: 'Optimum start sensitivity',      key: :optimum_start_sensitivity,    unit: Float   },
      { name: 'Regression R2',                  key: :regression_r2,                unit: Float   },
      { name: 'Average start time',             key: :average_start_time,           unit: Float   },
      { name: 'Start time standard deviation',  key: :start_time_standard_devation, unit: Float   },
      { name: 'Days data',                      key: :days,                         unit: Integer }
    ]

    header = row_config.map { |c| c[:name] }
    units  = row_config.map { |c| c[:unit] }

    keyed_data = row_config.map { |c| c[:key] }.compact
    rows = data.map do |day_type, raw_data|
      [day_type.to_s, keyed_data.map { |k| raw_data[k] }].flatten
    end

    table = HtmlTableFormatting.new(header, rows, nil, units)
    table.html
  end

  def interpreted_table_html(meter)
    analyser = BoilerStartAndEndTimeAnalysis.new(@school, meter)
    rows = [analyser.interpret.values]

    header = 'Fixed Start Time', 'Starts earlier on a Monday', 'Hours earlier on a Monday', 'Start Temperature Sensitive?'
    units = [TrueClass, TrueClass, Float, TrueClass]

    table = HtmlTableFormatting.new(header, rows, nil, units)
    table.html
  end
end
