require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

school_stub = 'bathampton-primary-school'

school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_stub, :unvalidated_meter_data)

chart_name = :electricity_cost_1_year_accounting_breakdown

chart_manager = ChartManager.new(school)
chart_data1 = chart_manager.run_standard_chart(chart_name)

existing_chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]

available = chart_manager.drilldown_available?(existing_chart_config)
puts "DRILLDOWN AVAILABLE #{available}"
column = chart_data1[:x_axis_ranges][1]
new_chart_name, new_chart_config = chart_manager.drilldown(chart_name, existing_chart_config, nil, column)
new_chart_results = chart_manager.run_chart(new_chart_config, new_chart_name)

existing_chart_config = new_chart_config

available = chart_manager.drilldown_available?(existing_chart_config)
puts "DRILLDOWN AVAILABLE #{available}"
column = new_chart_results[:x_axis_ranges][1]
new_chart_name, new_chart_config = chart_manager.drilldown(new_chart_name, existing_chart_config, nil, column)
new_chart_results2 = chart_manager.run_chart(new_chart_config, new_chart_name)

excel = ExcelCharts.new('Results\testchart.xlsx')

excel.add_charts('Test', [chart_data1, new_chart_results, new_chart_results2])

excel.close
