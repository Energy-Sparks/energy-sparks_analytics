# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'hashdiff'

ENV['ENERGYSPARKSTESTMODE'] = 'ON'

module Logging
  @logger = Logger.new('log/test-alerts ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
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

def print_all_results(alert_class, alert)
  @method_calls.each do |result|
    print_method(result[:on_class] ? alert_class : alert, result[:method], result[:name], result[:args], result[:use_puts])
  end
end

@method_calls = [
  { on_class: true,   method: :front_end_template_variables, name: 'Front end template variables', args: nil, use_puts: false },
  { on_class: false,  method: :raw_variables_for_saving, name: 'Raw data', args: nil, use_puts: false },
  { on_class: false,  method: :backwards_compatible_analysis_report, name: 'Backwards compatible alert report', args: nil, use_puts: true },
  { on_class: true,   method: :front_end_template_variables, name: 'Front end template variables', args: nil, use_puts: false },
  { on_class: false,  method: :text_template_variables, name: 'text data', args: nil, use_puts: false },
  { on_class: false,  method: :html_template_variables, name: 'Template variables', args: nil, use_puts: false },

=begin
  { on_class: false,  method: :raw_variables_for_saving, name: 'Raw data', args: nil, use_puts: false },
  { on_class: false,  method: :backwards_compatible_analysis_report, name: 'Backwards compatible alert report', args: nil, use_puts: true },
  { on_class: false,  method: :analysis_report, name: 'Original report', args: nil, use_puts: true },
  { on_class: false,  method: :html_template_variables, name: 'Template variables', args: nil, use_puts: false },
  { on_class: true,   method: :front_end_template_variables, name: 'Front end template variables', args: nil, use_puts: false },
  { on_class: true,   method: :front_end_template_charts, name: 'Front end chart results', args: nil, use_puts: false },
  { on_class: true,   method: :front_end_template_tables, name: 'Front end table results', args: nil, use_puts: false },
  { on_class: false,  method: :front_end_template_chart_data, name: 'Front end chart data', args: nil, use_puts: false },
  { on_class: false,  method: :front_end_template_table_data, name: 'Front end table data', args: nil, use_puts: false },
  { on_class: false,  method: :front_end_template_data, name: 'front end text data', args: nil, use_puts: false },
  { on_class: false,  method: :text_template_variables, name: 'text data', args: nil, use_puts: false },
  { on_class: false,  method: :summary_wording, name: 'html summary', args: :html, use_puts: true },
  { on_class: false,  method: :summary_wording, name: 'text summary', args: :text, use_puts: true },
  { on_class: false,  method: :summary_wording, name: 'html content', args: :html, use_puts: true },
  { on_class: false,  method: :content_wording, name: 'text content', args: :html, use_puts: true },
=end
]

alerts_to_test = { # classname => excel worksheet tab
  AlertWeekendGasConsumptionShortTerm         => 'WeekendGas',
  AlertChangeInDailyElectricityShortTerm      => 'ChangeInElectric',
  AlertHeatingComingOnTooEarly                => 'HeatingTooEarly',
  AlertChangeInDailyElectricityShortTerm      => 'LastWeekElectric',
  AlertChangeInDailyGasShortTerm              => 'LastWeekGas',
  AlertChangeInElectricityBaseloadShortTerm   => 'BaseloadChange',
  AlertHotWaterInsulationAdvice               => 'HWInsulation',
  AlertOutOfHoursElectricityUsage             => 'OutHoursElectric',
  AlertOutOfHoursGasUsage                     => 'OutHoursGas',
  AlertElectricityAnnualVersusBenchmark       => 'ElectricVBenchmark',
  AlertGasAnnualVersusBenchmark               => 'GasVBenchmark',
  AlertElectricityBaseloadVersusBenchmark     => 'BaseloadBenchmark',
  AlertHeatingOnOff                           => 'HeatingOnOff',
  AlertHeatingSensitivityAdvice               => 'HeatSenseAdvice',
  AlertHotWaterEfficiency                     => 'HWEfficiency',
  AlertImpendingHoliday                       => 'ImpendingHoliday',
  AlertHeatingOnNonSchoolDays                 => 'NonHeatingDays',
  AlertHeatingOnSchoolDays                    => 'HeatingDays',
  AlertThermostaticControl                    => 'Thermostatic'
}

excluded_schools = [] # ['Ecclesall Primary School', 'Selwood Academy', 'Athelstan Primary School', 'Walkley Tennyson School']
included_schools = nil # ['Whiteways Primary']

asof_date = Date.new(2019, 2, 15)

school_names = AnalysticsSchoolAndMeterMetaData.new.meter_collections.keys

alert_calculation_time = {}
school_calculation_time = {}

reports = ReportConfigSupport.new

failed_alerts = []
 
generate_charts = false
excel_charts = ReportConfigSupport.new if generate_charts

history = AlertHistoryDatabase.new
previous_results = history.load
puts 'Loaded data'
# ap(previous_results)

calculated_results = {}

school_names.sort.each do |school_name|
  next if excluded_schools.include?(school_name)
  # next unless !included_schools.nil? && included_schools.include?(school_name)

  print_banner(school_name, 2)

  school = reports.load_school(school_name, true)

  excel_charts.setup_school(school, school_name)  if generate_charts

  calculated_results[school.urn] = {}
  calculated_results[school.urn][asof_date] = {}

  alerts_classes = AlertAnalysisBase.all_available_alerts

  bm1 = Benchmark.realtime {
    alerts_classes.each do |alert_class|
      # next if !alerts_to_test.include?(alert_class)

      alert = alert_class.new(school)
      next unless alert.valid_alert?
      print_banner(alert.class.name,1)

      bm2 = Benchmark.realtime {
        alert.analyse(asof_date, true)

        raw_data = alert.raw_variables_for_saving

        calculated_results[school.urn][asof_date].merge!(raw_data)

        # print_all_results(alert_class, alert)

        results = alert.analysis_report
        if results.status == :failed
          failed_alerts.push(sprintf('%-32.32s: %s', school_name, alert.class.name))
        end
      }
      (alert_calculation_time[alert.class.name] ||= []).push(bm2)

      if generate_charts
        excel_tab_name = alerts_to_test[alert_class]
        charts = alert.front_end_template_chart_data.values.map(&:to_sym)
        puts "Saving charts to #{excel_tab_name}: #{charts.join(';')}"
        excel_charts.do_chart_list(excel_tab_name, charts, false) unless charts.empty?
      end
    end
  }

  (school_calculation_time[school_name] ||= []).push(bm1)
  if generate_charts
    excel_filename = File.join(File.dirname(__FILE__), '../TestResults/Alerts/Charts/') + school.name + ' alert charts ' + asof_date.strftime('%d%b%Y') + '.xlsx'
    puts "Writing to #{excel_filename}"
    excel_charts.write_excel(excel_filename)
  end
end

# ap(calculated_results)

history.save(calculated_results)

print_banner "Differences:"
h_diff = Hashdiff.diff(previous_results, calculated_results, use_lcs: false, :numeric_tolerance => 0.01)
puts h_diff

print_banner "Calc times:"
alert_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum / data.length)
end

school_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum)
end

print_banner "Failed alerts:"
failed_alerts.each do |fail|
    puts fail
end