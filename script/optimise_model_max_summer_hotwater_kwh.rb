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
    model = meter.heating_model(period, model_type = :best)
  end
end

school_name_pattern_match = ['a*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

results = {}
full_school_names = []

school_names.each do |school_name|
  puts "==============================Doing #{school_name} ================================"

  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  full_school_names.push(school.name)
  heat_meters = OptimiseMeterMaxSummerHotWaterKwh.heat_meters(school)

  heat_meters.each do |heat_meter|
    analyser = OptimiseMeterMaxSummerHotWaterKwh.new(heat_meter)
    key = sprintf '%-32.32s %14d', school.name.encode('utf-8'), heat_meter.mpan_mprn
    results[key] = nil
  end
end

ap SchoolFactory.unique_short_school_names_for_excel_worksheet_tab_names(full_school_names)

ap results.keys
