require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'ruby-prof'
require 'write_xlsx'

module Logging
  @logger = Logger.new('log/optimise model max summer hw kwh ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

class OptimiseMeterMaxSummerHotWaterKwh
  attr_reader :meter
  def initialize(meter)
    @meter = meter
  end

  def self.heat_meters(school)
    school.heat_meters
  end

  def analyse
    end_date = meter.amr_data.end_date
    start_date = [end_date - 364, meter.amr_data.start_date].max
    period = SchoolDatePeriod.new(:optimisation, 'optmisation', start_date, end_date)
    model = meter.heating_model(period, :simple_regression_temperature_no_overrides)

    {
      calculated_max_summer_hotwater_kwh: model.average_max_non_heating_day_kwh,
      overridden_max_summer_hotwater_kwh: overridden_max_summer_hot_water_kwh
    }
  end

  def overridden_max_summer_hot_water_kwh
    attributes = meter.attributes(:heating_model)
    return nil if attributes.nil?
    attributes.fetch(:max_summer_daily_heating_kwh, nil)
  end
end

def save_results_to_csv(results)
  filename = 'Results\\' + "max summer hot water kwh analysis.csv"
  variable_column_names = results.values.map { |v| v.keys }.flatten.uniq
  column_names = ['meter name', variable_column_names].flatten
  puts "Saving readings to #{filename}"
  CSV.open(filename, 'w') do |csv|
    csv << column_names
    results.each do |key, result|
      csv << [key, variable_column_names.map { |cn| result.fetch(cn, nil) }].flatten
    end
  end
end

school_name_pattern_match = ['a*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

results = {}
full_school_names = []
school = nil

school_names.each do |school_name|
  puts "==============================Doing #{school_name} ================================"

  begin
    school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)
    
    full_school_names.push(school.name)
    heat_meters = OptimiseMeterMaxSummerHotWaterKwh.heat_meters(school)

    heat_meters.each do |heat_meter|
      analyser = OptimiseMeterMaxSummerHotWaterKwh.new(heat_meter)
      analysis = analyser.analyse
      key = '%-32.32s %14d' % [school.name.encode('utf-8'), heat_meter.mpan_mprn]
      results[key] = analysis
    end
  rescue EnergySparksNotEnoughDataException => e
    puts "Giving up"
    puts e.message
  end
end

ap SchoolFactory.unique_short_school_names_for_excel_worksheet_tab_names(full_school_names)

ap results

save_results_to_csv(results)