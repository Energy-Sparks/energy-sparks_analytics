# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'hashdiff'

module Logging
  @logger = Logger.new('log/test-alerts ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def banner(title= '')
  len_before = ((80 - title.length) / 2).floor
  len_after = 80 - title.length - len_before
  '=' * len_before + title + '=' * len_after
end

@@parameterised = true

school_name = 'Freshford Primary School'
# school_name = 'St Michaels Junior Church School'

school_names = AnalysticsSchoolAndMeterMetaData.new.meter_collections.keys

ENV['School Dashboard Advice'] = 'Include Header and Body'
$SCHOOL_FACTORY = SchoolFactory.new

alert_calculation_time = {}
school_calculation_time = {}

reports = ReportConfigSupport.new

failed_alerts = []

history = AlertHistoryDatabase.new
=begin
previous_results = history.load
puts 'Loaded data'
ap(previous_results)
=end
calculated_results = {}

school_names.sort.each do |school_name|
  next if ['Ecclesall Primary School', 'Selwood Academy'].include?(school_name)
  next unless ['Whiteways Primary'].include?(school_name)
  puts banner
  puts banner
  puts banner(school_name)
  puts banner
  puts banner

  school = reports.load_school(school_name, true)

  calculated_results[school.urn] = {}

  asof_date = Date.new(2019, 2, 15)

  calculated_results[school.urn][asof_date] = {}

  alerts_classes = AlertAnalysisBase.all_available_alerts

  bm1 = Benchmark.realtime {
    alerts_classes.each do |alert_class|
      next if ![
        AlertHeatingComingOnTooEarly
        
=begin
        AlertChangeInDailyElectricityShortTerm,
        AlertChangeInDailyGasShortTerm,
        AlertChangeInElectricityBaseloadShortTerm,
        AlertHotWaterInsulationAdvice,
        AlertOutOfHoursElectricityUsage,
        AlertOutOfHoursGasUsage,
        AlertElectricityAnnualVersusBenchmark,
        AlertGasAnnualVersusBenchmark,
        AlertWeekendGasConsumptionShortTerm
=end
      ].include?(alert_class)

      alert = alert_class.new(school)
      next unless alert.valid_alert?
      results = 'No results'
      puts banner(alert.class.name)
      bm2 = Benchmark.realtime {

        alert.analyse(asof_date, true)

        raw_data = alert.raw_variables_for_saving

        calculated_results[school.urn][asof_date].merge!(raw_data)

        ap(raw_data)

        ap(alert.html_template_variables)

        puts ">>>>front end chart results:"
        ap(alert_class.front_end_template_charts)
        puts ">>>>front end table results:"
        ap(alert_class.front_end_template_tables)
        puts ">>>>chart data"
        ap(alert.front_end_template_chart_data)
        puts ">>>>table data"
        ap(alert.front_end_template_table_data)

=begin
        puts ">>>>All template variables:"
        ap(alert_class.front_end_template_variables)
        puts ">>>>front end text results:"
        ap(alert.front_end_template_data)
        puts ">>>>front end chart results:"
        ap(alert.front_end_template_charts)
        puts ">>>>front end table results:"
        ap(alert.front_end_template_tables)
=end
=begin
        puts ">>>>All template variables:"
        ap(alert_class.front_end_template_variables)

        puts ">>>>Raw template variables:"
        ap(alert.raw_template_variables)
        puts ">>>>html results:"
        ap(alert.html_template_variables)
=end
        puts ">>>>All template variables:"
        ap(alert_class.front_end_template_variables)
        puts ">>>>front end text results:"
        ap(alert.front_end_template_data)
        puts ">>>>front end chart results:"
        ap(alert_class.front_end_template_charts)
        puts ">>>>front end table results:"
        ap(alert_class.front_end_template_tables)
=begin
        puts ">>>>text results:"
        ap(alert.text_template_variables)
        puts "html summary"
        puts alert.summary_wording(:html)
        puts "text summary"
        puts alert.summary_wording(:text)
        puts "html content"
        puts alert.content_wording(:html)
        puts "text content"
        puts alert.content_wording(:text)

        puts 'Backwards compatible alert report>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
        puts alert.backwards_compatible_analysis_report
        puts 'Original Report<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
=end
        results = alert.analysis_report
        puts results
        puts '==================================================================='

        if results.status == :failed
          failed_alerts.push(sprintf('%-32.32s: %s', school_name, alert.class.name))
        end
      }
      (alert_calculation_time[alert.class.name] ||= []).push(bm2)
    end
  }
  (school_calculation_time[school_name] ||= []).push(bm1)
end

# ap(calculated_results)

=begin
history.save(calculated_results)

h_diff = HashDiff.diff(previous_results, calculated_results, use_lcs: false, :numeric_tolerance => 0.01)
puts h_diff
=end

alert_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum/data.length)
end

school_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum)
end

failed_alerts.each do |fail|
    puts fail
end