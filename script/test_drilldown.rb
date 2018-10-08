# test chart drilldown
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
#  @logger = Logger.new('log/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
#  logger.level = :debug
end

def random_drilldown(array_data)
  array_index = Random.rand(array_data.length)
  array_data[array_index]
end

def run_all_series(chart_manager, existing_chart_name, existing_chart_config, existing_chart_results)
  chart_results =  []
  # run chart for each series_name
  existing_chart_results[:x_data].each_key do |series_name|
    # run random x axis drilldown
    name, chart, results = run_drilldown_chart_random_xaxis(chart_manager, existing_chart_name, existing_chart_config, existing_chart_results, series_name, true)
    chart_results.push(results)
    # run without x axis drilldown
    name, chart, results = run_drilldown_chart_random_xaxis(chart_manager, existing_chart_name, existing_chart_config, existing_chart_results, series_name, false)
    chart_results.push(results)
  end

  # run chart with all series, but random x_axis drilldown
  name, chart, last_result = run_drilldown_chart_random_xaxis(chart_manager, existing_chart_name, existing_chart_config, existing_chart_results, nil, true)
  chart_results.push(last_result)
  [name, chart, last_result, chart_results]
end

def run_drilldown_chart_random_xaxis(chart_manager, existing_chart_name, existing_chart_config, existing_chart_results, series_name_drilldown, random_x_axis)
  x_axis_drilldown = random_x_axis ? random_drilldown(existing_chart_results[:x_axis_ranges]) : nil

  new_chart_name, new_chart = chart_manager.drilldown(existing_chart_name, existing_chart_config, series_name_drilldown, x_axis_drilldown)

  new_chart_results = chart_manager.run_chart(new_chart, new_chart_name)

  [new_chart_name, new_chart, new_chart_results]
end

# worksheet names are limited to 31 chars; camelize, and overwrite last few characters if too long
def worksheet_name_shorten(chart_name)
  chart_name_split = chart_name.to_s.split('_')
  chart_name = chart_name_split.collect(&:capitalize).join
  if chart_name.length > 30
    insertion_point = 30 - chart_name_split.last.length
    chart_name = chart_name[0..insertion_point] + chart_name_split.last.capitalize
  end
  chart_name
end

def test_drilldown_of_dashboard_chart(base_chart_name, reports)
  test_charts = []
  worksheet_tab_name = worksheet_name_shorten(base_chart_name)

  chart_manager = reports.chart_manager

  existing_chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[base_chart_name]
  chart_results = chart_manager.run_chart(existing_chart_config, base_chart_name)
  test_charts.push(chart_results)

  while (!chart_results.nil? && chart_manager.drilldown_available(existing_chart_config))
    base_chart_name, existing_chart_config, chart_results, all_charts = run_all_series(chart_manager, base_chart_name, existing_chart_config, chart_results)

    test_charts += all_charts
  end
  [worksheet_tab_name, test_charts]
end

# MAIN

reports = ReportConfigSupport.new

school_name = 'St Marks Secondary'
ReportConfigSupport.suppress_output(school_name) {
  reports.load_school(school_name, true)
}

reports.do_chart_list('Baseline', [:benchmark])

# ENV['AWESOMEPRINT'] = 'on'

chart_list_for_page = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:main_dashboard_electric_and_gas][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:electricity_detail][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:gas_detail][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:boiler_control][:charts]
chart_list_for_page =  [:hotwater]

total_charts = 0

chart_list_for_page.each do |dashboard_chart_name|
  puts "=" * 100
  puts "Testing #{dashboard_chart_name}"
  puts "=" * 100

  worksheet_name, chart_results = test_drilldown_of_dashboard_chart(dashboard_chart_name, reports)

  total_charts += chart_results.length

  puts "=" * 1000
  puts "Testing #{worksheet_name} x #{chart_results.length}"
  puts "=" * 1000

  reports.worksheet_charts[worksheet_name] = chart_results
end

reports.worksheet_charts.each_key do |name|
  puts "Workheet>>>> name #{name}"
end

reports.save_excel_and_html

reports.report_benchmarks

puts "Completed test of #{total_charts} charts"
