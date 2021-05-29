require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/meter-drilldown ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end

school_stub = 'n3rgy-tiered-tariffs'

school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_stub, :unvalidated_meter_data)

chart_name = :electricity_cost_1_year_accounting_breakdown

puts '=' * 80
puts "Chart: #{chart_name}"
chart_manager = ChartManager.new(school)
chart_data1 = chart_manager.run_standard_chart(chart_name)

existing_chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
ap existing_chart_config

charts = [chart_data1]

while chart_manager.drilldown_available?(existing_chart_config) do
  puts '=' * 80
  column = chart_data1[:x_axis_ranges][1]
  new_chart_name, new_chart_config = chart_manager.drilldown(chart_name, existing_chart_config, nil, column)
  puts "Chart: #{chart_name}"
  ap new_chart_config
  new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)
  charts.push(new_chart_results)
  existing_chart_config = new_chart_config
end
puts '=' * 80

excel = ExcelCharts.new('Results\testchart.xlsx')

excel.add_charts('Test', charts)

excel.close
