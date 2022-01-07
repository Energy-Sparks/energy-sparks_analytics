# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'hashdiff'

class RunAlerts < RunAnalyticsTest
  def initialize(school)
    super(school, :alert)
  end

  def run_alerts(alerts, control, asof_date)
    alerts = AlertAnalysisBase.all_available_alerts if alerts.nil?

    class_names_to_excel_tab_names(alerts)

    alerts.sort_by(&:name).each do |alert_class|

      alert = alert_class.new(@school)

      log_result(alert, 'Meter out of date') unless alert.meter_readings_up_to_date_enough?

      unless alert.valid_alert?
        log_result(alert, 'Invalid alert before analysis') if control[:log].include?(:invalid_alerts)
        next
      end

      RecordTestTimes.instance.record_time(@school.name, 'alerts', alert.class.name){
        alert.analyse(asof_date, true)
      }

      print_results(alert_class, alert, control[:outputs])

      save_to_yaml_and_compare_results(alert_class, alert, control, asof_date)

      log_results(alert, control)
    end
  end

  private

  def save_to_yaml_and_compare_results(alert_class, alert, control, asof_date)
    results = control[:compare_results][:methods].map do |method|
      [method, method_call_results(alert_class, alert, method) ]
    end.to_h

    compare_results(control, alert_class.name, results, asof_date)
  end

  def print_results(alert_class, alert, methods)
    return if methods.nil?

    print_banner(alert_class.name.to_s)
    methods.each do |method|
      ap method_call_results(alert_class, alert, method)
    end
  end

  def method_call_results(alert_class, alert, method)
    if alert.respond_to?(method)
      alert.public_send(method)
    else
      alert_class.public_send(method)
    end
  end

  def log_results(alert, control)
    msg = error_message(alert)

    if msg.nil?
      unless alert.make_available_to_users?
        log_result(alert, 'Not make_available_to_users after analysis')
      else
        log_result(alert, 'Calculated succesfully') if control[:log].include?(:sucessful_calculations)
      end
    else
      log_result(alert, msg)
    end
  end

  def error_message(alert)
    return nil if alert.error_message.nil?
    "#{alert.error_message}: #{alert.backtrace.first.split('/').last}"
  end

  def log_result(alert, message)
    puts "#{sprintf('%-50.50s', alert.class.name)} #{message}"
  end
end
