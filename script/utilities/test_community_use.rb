# Centrica
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

ENV['ENERGYSPARKSMETERCOLLECTIONDIRECTORY'] += '\Community'

module Logging
  @logger = Logger.new('log/community use ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end

def calculate_charts_with_and_without_community_use(school, chart_name, non_community_meter_name)
  charts = []

  chart_manager = ChartManager.new(school)

  existing_chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]

  ChartYAxisManipulation.new(school).y1_axis_choices(existing_chart_config).each do |y1_axis_unit|
    chart_config = ChartYAxisManipulation.new(school).change_y1_axis_config(existing_chart_config, y1_axis_unit)

    chart_data = chart_manager.run_chart(chart_config, chart_name, true)
    charts.push(chart_data)

    community_chart_config = chart_config.merge( { meter_definition: non_community_meter_name, name: "#{chart_config[:name]} #{non_community_meter_name}" } )

    chart_data = chart_manager.run_chart(community_chart_config, chart_name, true)
    charts.push(chart_data)
  end

  charts
end

def intraday_chart(school, chart_name)
  charts = []
  chart_manager = ChartManager.new(school)
  existing_chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
  chart_data = chart_manager.run_chart(existing_chart_config, chart_name, true)
  charts.push(chart_data)
end

def random_dates(school)
  [
    (Date.new(2020, 12, 28)..Date.new(2021, 1, 10)).to_a
  ].flatten.each do |date|
    puts "==========#{date}=================================="
    data_type = :co2
    school.open_close_times.print_usages(date)
    usage = school.open_close_times
    amr = AMRDataCommunityOpenCloseBreakdown.new(school.aggregated_electricity_meters, usage)
    amr.compact_print_weights(date)
    school.aggregated_electricity_meters.amr_data.days_kwh_x48(date, data_type)
    school.aggregated_electricity_meters.amr_data.open_close_breakdown.days_kwh_x48(date, data_type)
    usage = school.open_close_times
    puts "-" * 100
  end
end

profiler = false

school_name_pattern_match = ['green*']
source_db = :unvalidated_meter_data
charts = []

school_name = RunTests.resolve_school_list(source_db, school_name_pattern_match).first
school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

RubyProf.start if profiler

# random_dates(school)

charts = []
charts += intraday_chart(school, :management_dashboard_group_by_week_electricity)
charts += intraday_chart(school, :management_dashboard_group_by_week_gas)
charts += intraday_chart(school, :community_use_test_electricity)
charts += intraday_chart(school, :community_use_test_gas)

if profiler
  prof_result = RubyProf.stop
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('log\code-profile - ' + Date.today.to_s + '.html','w'))
end

filename = 'Results\\test-community-use.xlsx'

excel = ExcelCharts.new(filename)

excel.add_charts('Test', charts)

excel.close

RecordTestTimes.instance.print_stats
RecordTestTimes.instance.save_summary_stats_to_csv
