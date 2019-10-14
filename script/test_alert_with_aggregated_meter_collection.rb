# test alerts
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'hashdiff'
require 'yaml'

module Logging
  @logger = Logger.new('log/test-alert-with-aggregated-meter-collection-' + Time.now.strftime('%H-%M') + '.log')
  logger.level = :debug
end

class AlertRunner
  include Logging

  def initialize(yaml_file_name, alert_class, analysis_date)
    @yaml_file_name = yaml_file_name
    @alert_class = alert_class
    @analysis_date = analysis_date
    @school_name = meter_collection.name
  end

  def meter_collection
    @meter_collection ||= YAML.load_file("InputData/#{@yaml_file_name}")
  end

  def run_alert
    analysis_object = @alert_class.new(meter_collection)
    logger.info "Running #{@alert_class} alert for #{@school_name} - valid? : #{analysis_object.valid_alert?}"

    if analysis_object.valid_alert?

      analysis_object.analyse(@analysis_date)
      logger.info "Running #{@alert_class} alert for #{@school_name} - enough_data? : #{analysis_object.enough_data}"
      logger.info "Running #{@alert_class} alert for #{@school_name} - relevant? : #{analysis_object.relevance}"
      logger.info "Running #{@alert_class} alert for #{@school_name} - rating? : #{analysis_object.rating}"

      if (analysis_object.enough_data == :enough) && (analysis_object.relevance == :relevant)
        {
          template_data: analysis_object.front_end_template_data,
          chart_data:    analysis_object.front_end_template_chart_data,
          table_data:    analysis_object.front_end_template_table_data,
          priority_data: analysis_object.priority_template_data
        }
      else
        {}
      end
    end
  end
end

AlertRunner.new('aggregated-meter-collection-king-edward-vii-upper-school.yaml', AlertPreviousHolidayComparisonElectricity, Date.parse('10/10/2019')).run_alert
#AlertRunner.new('aggregated-meter-collection-king-edward-vii-upper-school.yaml', AlertHotWaterEfficiency, Date.today).run_alert
