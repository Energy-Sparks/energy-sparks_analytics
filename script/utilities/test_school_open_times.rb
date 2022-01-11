# Centrica
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/chart-y_axis_manipulation ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end

ENV['ENERGYSPARKSMETERCOLLECTIONDIRECTORY'] += '\Working'
school_name_pattern_match = ['king-j*']
source_db = :unvalidated_meter_data
chart_name = :gas_longterm_trend
charts = []

school_name = RunTests.resolve_school_list(source_db, school_name_pattern_match).first
school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

ap SchoolOpenCloseTimes.example_open_close_times(school)
