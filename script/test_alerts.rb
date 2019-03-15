# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-alerts ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def banner(title= '')
  len_before = ((80 - title.length) / 2).floor
  len_after = 80 - title.length - len_before
  '=' * len_before + title + '=' * len_after
end

school_name = 'St Marks Secondary'
# school_name = 'St Michaels Junior Church School'

school_names = AnalysticsSchoolAndMeterMetaData.new.meter_collections.keys

ENV['School Dashboard Advice'] = 'Include Header and Body'
$SCHOOL_FACTORY = SchoolFactory.new

alert_calculation_time = {}
school_calculation_time = {}

reports = ReportConfigSupport.new

failed_alerts = []

school_names.sort.each do |school_name|
  # next if school_name != 'Coit Primary School'
  puts banner
  puts banner
  puts banner(school_name)
  puts banner
  puts banner

  school = reports.load_school(school_name, true)

  asof_date = Date.new(2019, 2, 15)

  alerts = AlertAnalysisBase.all_available_alerts(school)

  bm1 = Benchmark.realtime {
    alerts.each do |alert|
      next unless alert.valid_alert?
      results = 'No results'
      puts banner(alert.class.name)
      bm2 = Benchmark.realtime {
        alert.analyse(asof_date, true)
        results = alert.analysis_report
        if results.status == :failed
          failed_alerts.push(sprintf('%-32.32s: %s', school_name, alert.class.name))
        end
      }
      (alert_calculation_time[alert.class.name] ||= []).push(bm2)
      puts results
    end
  }
  (school_calculation_time[school_name] ||= []).push(bm1)
end

alert_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum/data.length)
end

school_calculation_time.each do |type, data|
  puts sprintf('%-35.35s %.6f', type, data.sum)
end

failed_alerts.each do |fail|
    puts fail
end