require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'ruby-prof'
require 'sun'

profile = false

module Logging
  @logger = Logger.new('log/pv estimator ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

school_name_pattern_match = ['*'] # , '*indm*'] # ['*aulto*', '*utton*', '*alph*', '*artin*', '*ecott*', '*allif*', '*exey*']
source_db = :aggregated_meter_collection # :analytics_db

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

school_names.each do |school_name|
  puts "==============================Doing #{school_name} ================================"

  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)
  estimator = ExistingSolarPVCapacityEstimator.new(school)
  ap estimator.calculate
end
