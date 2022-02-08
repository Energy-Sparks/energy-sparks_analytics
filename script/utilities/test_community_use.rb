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

def test_community_use_breakdowns(school)
  d = Date.new(2021,11,4)

  tests = [
    nil,
    { filter: :community_only, aggregate: :none },
    { filter: :school_only, aggregate: :none },
    { filter: :all, aggregate: :none },
    { filter: :all, aggregate: :all_to_single_value },
    { filter: :all, aggregate: :all_to_single_value },
    { filter: :all, aggregate: :community_use },
    { filter: :community_only, aggregate: :all_to_single_value },
    { filter: :school_only, aggregate: :all_to_single_value },
  ]

  tests.each do |test|
    puts "=" * 100
    ap test
    puts 'one_day_kwh'
    ap school.aggregated_electricity_meters.amr_data.one_day_kwh(d, :kwh, community_use: test)
    puts 'kwh'
    ap school.aggregated_electricity_meters.amr_data.kwh(d, 10, :kwh, community_use: test)
    puts 'days_kwh_x48'
    ap school.aggregated_electricity_meters.amr_data.days_kwh_x48(d, :kwh, community_use: test)
    puts 'kwh_date_range'
    ap school.aggregated_electricity_meters.amr_data.kwh_date_range(d, d + 7, :kwh, community_use: test)
  end
end

def run_charts(school)
  charts = []

  if school.electricity?
    charts += intraday_chart(school, :management_dashboard_group_by_week_electricity)
    charts += intraday_chart(school, :community_use_test_electricity)
    charts += intraday_chart(school, :community_use_test_electricity_community_use_only)
    charts += intraday_chart(school, :community_use_test_electricity_school_use_only)
    charts += intraday_chart(school, :community_use_test_electricity_community_use_only_aggregated)
  end

  if school.gas?
    charts += intraday_chart(school, :management_dashboard_group_by_week_gas)
    charts += intraday_chart(school, :community_use_test_gas)
    charts += intraday_chart(school, :schoolweek_alert_2_week_comparison_for_internal_calculation_gas_unadjusted_community_only)
    charts += intraday_chart(school, :schoolweek_alert_2_week_comparison_for_internal_calculation_gas_adjusted_community_only)
  end

  charts
end

profiler = false

filename = 'Results\\test-community-use.xlsx'
school_name_pattern_match = ['KJ*', 'bath*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

RubyProf.start if profiler


excel = ExcelCharts.new(filename)

school_names.each do |school_name|
  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)

  # test_community_use_breakdowns(school)

  # random_dates(school)
  
  charts = run_charts(school)

  excel_school_name = school_name.gsub(' ', '').gsub('-', '')[0..10]

  excel.add_charts(excel_school_name, charts)
end

if profiler
  prof_result = RubyProf.stop
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('log\code-profile - ' + Date.today.to_s + '.html','w'))
end

excel.close

RecordTestTimes.instance.print_stats
RecordTestTimes.instance.save_summary_stats_to_csv
