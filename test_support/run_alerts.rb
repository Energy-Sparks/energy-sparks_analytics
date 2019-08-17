# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'hashdiff'

class RunAlerts
  ALERT_TO_EXCELTAB_MAP = { # classname => excel worksheet tab name
    AlertWeekendGasConsumptionShortTerm           => 'WeekendGas',
    AlertChangeInDailyElectricityShortTerm        => 'ChangeInElectric',
    AlertHeatingComingOnTooEarly                  => 'HeatingTooEarly',
    AlertChangeInDailyElectricityShortTerm        => 'LastWeekElectric',
    AlertChangeInDailyGasShortTerm                => 'LastWeekGas',
    AlertChangeInElectricityBaseloadShortTerm     => 'BaseloadChange',
    AlertHotWaterInsulationAdvice                 => 'HWInsulation',
    AlertOutOfHoursElectricityUsage               => 'OutHoursElectric',
    AlertOutOfHoursGasUsage                       => 'OutHoursGas',
    AlertElectricityAnnualVersusBenchmark         => 'ElectricVBenchmark',
    AlertGasAnnualVersusBenchmark                 => 'GasVBenchmark',
    AlertElectricityBaseloadVersusBenchmark       => 'BaseloadBenchmark',
    AlertHeatingOnOff                             => 'HeatingOnOff',
    AlertHeatingSensitivityAdvice                 => 'HeatSenseAdvice',
    AlertHotWaterEfficiency                       => 'HWEfficiency',
    AlertImpendingHoliday                         => 'ImpendingHoliday',
    AlertHeatingOnNonSchoolDays                   => 'NonHeatingDays',
    AlertHeatingOnSchoolDays                      => 'HeatingDays',
    AlertThermostaticControl                      => 'Thermostatic',
    AlertElectricityMeterConsolidationOpportunity => 'MeterConsolidElectric',
    AlertGasMeterConsolidationOpportunity         => 'MeterConsolidGas',
    AlertMeterASCLimit                            => 'ASCLimit',
    AlertDifferentialTariffOpportunity            => 'DiffTariffOpp',
    AlertSchoolWeekComparisonElectricity          => 'SchWeekElectric',
    AlertPreviousHolidayComparisonElectricity     => 'PrevHolElectric',
    AlertPreviousYearHolidayComparisonElectricity => 'PrevYearHolElectric',
    AlertSchoolWeekComparisonGas                  => 'SchWeekGas',
    AlertPreviousHolidayComparisonGas             => 'PrevHolGas',
    AlertPreviousYearHolidayComparisonGas         => 'PrevYearHolGas',
  }.freeze

  RESULT_CALCULATION_METHOD_CALLS = {
    front_end_template_variables:   { on_class: true,   method: :front_end_template_variables, name: 'Front end template variables', args: nil, use_puts: false },
    raw_variables_for_saving:       { on_class: false,  method: :raw_variables_for_saving, name: 'Raw data', args: nil, use_puts: false },
    backwards_compatible_analysis_report: { on_class: false,  method: :backwards_compatible_analysis_report, name: 'Backwards compatible alert report', args: nil, use_puts: true },
    text_template_variables:        { on_class: false,  method: :text_template_variables, name: 'text data', args: nil, use_puts: false },
    html_template_variables:        { on_class: false,  method: :html_template_variables, name: 'Template variables', args: nil, use_puts: false },
    analysis_report:                { on_class: false,  method: :analysis_report, name: 'Original report', args: nil, use_puts: true },
    front_end_template_charts:      { on_class: true,   method: :front_end_template_charts, name: 'Front end chart results', args: nil, use_puts: false },
    front_end_template_tables:      { on_class: true,   method: :front_end_template_tables, name: 'Front end table results', args: nil, use_puts: false },
    front_end_template_chart_data:  { on_class: false,  method: :front_end_template_chart_data, name: 'Front end chart data', args: nil, use_puts: false },
    front_end_template_table_data:  { on_class: false,  method: :front_end_template_table_data, name: 'Front end table data', args: nil, use_puts: false },
    front_end_template_data:        { on_class: false,  method: :front_end_template_data, name: 'front end text data', args: nil, use_puts: false },
    summary_wording_html:           { on_class: false,  method: :summary_wording, name: 'html summary', args: :html, use_puts: true },
    summary_wording_text:           { on_class: false,  method: :summary_wording, name: 'text summary', args: :text, use_puts: true },
    summary_content_html:           { on_class: false,  method: :summary_wording, name: 'html content', args: :html, use_puts: true },
    summary_content_text:           { on_class: false,  method: :content_wording, name: 'text content', args: :html, use_puts: true },
  }.freeze

  attr_reader :school

  def initialize(school)
    @school = school
    @alert_calculation_time = {}
    @school_calculation_time = 0.0
  end

  def print_method(obj, method, name, arg = nil, use_puts = false)
    print_banner(name)
    if arg.nil?
      use_puts ? puts(obj.public_send(method)) : ap(obj.public_send(method))
    else
      use_puts ? puts(obj.public_send(method, arg)) : ap(obj.public_send(method, arg))
    end
  end

  def print_banner(title, lines_before_after = 0)
    lines_before_after.times { puts banner }
    puts banner(title)
    lines_before_after.times { puts banner }
  end

  def banner(title= '')
    len_before = ((150 - title.length) / 2).floor
    len_after = 150 - title.length - len_before
    '=' * len_before + title + '=' * len_after
  end

  def print_all_results(alert_class, alert, control)
    methods = control[:outputs].map { |key| RESULT_CALCULATION_METHOD_CALLS[key] }
    methods.each do |result|
      print_method(result[:on_class] ? alert_class : alert, result[:method], result[:name], result[:args], result[:use_puts])
    end
  end

  def save_yaml_file(filename, data)
    # puts "Saving data to #{full_filename(filename)}"
    File.open(full_filename(filename, false), 'w') { |f| f.write(YAML.dump(data)) }
  end

  def load_yaml_file(filename)
    full_name = full_filename(filename, true)
    return nil unless File.exist?(full_name)
    YAML.load_file(full_name)
  end

  def full_filename(filename, base)
    if base
      File.join(File.dirname(__FILE__), '../TestResults/Alerts/Base/') + filename
    else
      File.join(File.dirname(__FILE__), '../TestResults/Alerts/New/') + filename
    end
  end

  def yaml_filename(alert_type, output_type, asof_date)
    "#{@school.name} #{asof_date.strftime('%Y%m%d')} #{alert_type} #{output_type}.yml" 
  end

  def save_and_compare(alert_class, alert, control, asof_date)
    control[:save_and_compare][:data].each do |result_type|
      result = RESULT_CALCULATION_METHOD_CALLS[result_type]
      filename = yaml_filename(alert_class, result[:method], asof_date)
      obj = result[:on_class] ? alert_class : alert
      data = result[:args].nil? ? obj.public_send(result[:method]) : obj.public_send(result[:method], result[:args])
      save_yaml_file(filename, data)
      data = remove_volatile_data(data, alert_class, result_type)
      previous_data = load_yaml_file(filename)
      previous_data = remove_volatile_data(previous_data, alert_class, result_type)
      differs = data != previous_data
      puts "differs: #{filename}" if !control[:save_and_compare][:summary].nil? && differs
      if differs && !control[:save_and_compare][:h_diff].nil?
        h_diff = HashDiff.diff(previous_data, data, control[:save_and_compare][:h_diff]) do |_path, obj1, obj2|
          obj1.is_a?(Float) && obj2.is_a?(Float) && obj1.nan? && obj2.nan? ? true : nil # make NaN == NaN, produces a [] result
        end
        ap h_diff
      end
    end
  end

  def remove_volatile_data(data, alert_type, result_type)
    if alert_type == AlertHeatingOnOff # .is_? doesn't seem to work
      if result_type == :raw_variables_for_saving || result_type == :front_end_template_data
        [ 'Average overnight temperature', 'Average day time temperature', 'Cloud',
          'Potential Saving(-cost)', 'Potential saving(-cost)', 'forecast_date_time',
          'potential_saving_next_week_', 'next_weeks_predicted_consumption_',
          'percent_saving_next_week', 'Heating recommendation', 'Type of day',
          'days_between_forecast_and_last_meter_date'
        ].each do |match|
          data.delete_if { |key, _value| key.to_s.include?(match) }
        end
      elsif result_type == :front_end_template_data
        data.delete_if { |key, _value| key.to_s == :forecast_date_time }
        data.delete_if { |key, _value| key.to_s == :days_between_forecast_and_last_meter_date }
      elsif result_type == :front_end_template_table_data
        data.delete_if { |key, _value| key.to_s.include?('weather_forecast_table') }
      end
    end
    data
  end

  def run_charts(alert)
    return if alert.front_end_template_chart_data.empty? 
    control = {
      charts: [ adhoc_worksheet: { name: 'Test', charts: [ alert.front_end_template_chart_data ] } ],
      control: {
        report_failed_charts:   :summary,
        compare_results:        [ :summary, :report_differing_charts, :report_differences ] 
      }
    }
    charts = RunCharts.new(@school)
    charts.run(chart_list, control)
  end

  def run_alerts(alerts, control)
    asof_date = control[:asof_date]

    alerts = ALERT_TO_EXCELTAB_MAP.keys if alerts.nil?

    print_banner(@school.name, 0) unless control[:print_school_name_banner].nil?

    # reports = ReportConfigSupport.new

    failed_alerts = []
 
    generate_charts = false
    # excel_charts = ReportConfigSupport.new if generate_charts

    unless control[:alerts_history].nil?
      history = AlertHistoryDatabase.new
      previous_results = history.load
    end

    # ap(previous_results)

    calculated_results = {}

    # excel_charts.setup_school(school, school_name)  if generate_charts

    calculated_results[asof_date] = {}

    bm1 = Benchmark.realtime {
      alerts.each do |alert_class|

        alert = alert_class.new(school)
        next unless alert.valid_alert?
        print_banner(alert.class.name, 1) unless control[:print_alert_banner].nil?

        bm2 = Benchmark.realtime {
          alert.analyse(asof_date, true)
          next unless alert.make_available_to_users?
          raw_data = alert.raw_variables_for_saving

          calculated_results[asof_date].merge!(raw_data)

          print_all_results(alert_class, alert, control) if control.key?(:outputs)

          save_and_compare(alert_class, alert, control, asof_date) if control.key?(:save_and_compare)

          failed_alerts.push(sprintf('%-32.32s: %s', @school.name, alert.class.name)) unless alert.calculation_worked
        }
        (@alert_calculation_time[alert.class.name] ||= []).push(bm2)

        if false && generate_charts
          excel_tab_name = alerts_to_test[alert_class]
          charts = alert.front_end_template_chart_data.values.map(&:to_sym)
          puts "Saving charts to #{excel_tab_name}: #{charts.join(';')}"
          excel_charts.do_chart_list(excel_tab_name, charts, false) unless charts.empty?
        end
      end
    }
    if false && generate_charts
      excel_filename = File.join(File.dirname(__FILE__), '../TestResults/Alerts/Charts/') + school.name + ' alert charts ' + asof_date.strftime('%d%b%Y') + '.xlsx'
      puts "Writing to #{excel_filename}"
      excel_charts.write_excel(excel_filename)
    end
  end

  def output_results
    # ap(calculated_results)

    history.save(calculated_results)

    print_banner "Differences:"
    h_diff = HashDiff.diff(previous_results, calculated_results, use_lcs: false, :numeric_tolerance => 0.01)
    puts h_diff

    print_banner "Calc times:"
    @alert_calculation_time.each do |type, data|
      puts sprintf('%-35.35s %.6f', type, data.sum / data.length)
    end

    school_calculation_time.each do |type, data|
      puts sprintf('%-35.35s %.6f', type, data.sum)
    end

    print_banner "Failed alerts:"
    failed_alerts.each do |fail|
      puts fail
    end
  end
end
