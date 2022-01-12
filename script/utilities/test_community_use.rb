# Centrica
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

ENV['ENERGYSPARKSMETERCOLLECTIONDIRECTORY'] += '\Working'

module Logging
  @logger = Logger.new('log/community use ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end

def calculate_charts_with_and_without_community_use(school, chart_name, non_community_meter_name)
  charts = []

  chart_manager = ChartManager.new(school)

  chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]

  chart_data = chart_manager.run_chart(chart_config, chart_name)
  charts.push(chart_data)

  chart_config.merge!( { meter_definition: non_community_meter_name, name: "#{chart_config[:name]} #{non_community_meter_name}" } )

  chart_data = chart_manager.run_chart(chart_config, chart_name)
  charts.push(chart_data)

  charts
end

school_name_pattern_match = ['king-j*']
source_db = :unvalidated_meter_data
chart_name = 
charts = []

school_name = RunTests.resolve_school_list(source_db, school_name_pattern_match).first
school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

charts =  calculate_charts_with_and_without_community_use(school, :gas_longterm_trend, :allheat_without_community_use)
charts += calculate_charts_with_and_without_community_use(school, :electricity_longterm_trend, :allelectricity_without_community_use )
filename = 'Results\\test-community-use.xlsx'

excel = ExcelCharts.new(filename)

excel.add_charts('Test', charts)

excel.close

RecordTestTimes.instance.print_stats
RecordTestTimes.instance.save_summary_stats_to_csv
