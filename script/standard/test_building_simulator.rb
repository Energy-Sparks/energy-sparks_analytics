require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'ruby-prof'

profile = false

module Logging
  @logger = Logger.new('log/building simulation ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

school_name_pattern_match = ['*athampton*']
source_db = :aggregated_meter_collection # :analytics_db

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

school_names.each do |school_name|
  puts "==============================Doing #{school_name} ================================"

  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)
  RubyProf.start if profile
  simulator = BuildingHeatBalanceSimulator.new(school, Date.new(2018, 9, 1), Date.new(2019, 8, 31), 1)
  simulator.simulate
  if profile
    prof_result = RubyProf.stop
    printer = RubyProf::GraphHtmlPrinter.new(prof_result)
    printer.print(File.open('log\code-profile - test_building_simulator' + Date.today.to_s + '.html','w')) # 'code-profile.html')
  end
end
