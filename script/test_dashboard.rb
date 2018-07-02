# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

reports = DashboardReports.new

reports.load_school('Paulton Junior School', true)

# testing examples
#
#   reports.do_all_schools(true)
#   reports.do_all_standard_pages_for_school
#   reports.do_one_page(:main_dashboard_electric_and_gas)
#   reports.do_chart_list('Boiler Control', [:hotwater, :frost_2, :optimum_start])
#

# reports.do_all_schools(true)

# comment excel/html out if calling reports.do_all_schools or reports.do_all_standard_pages_for_school
# as done automatically:

# reports.do_chart_list('Boiler Control', [ :group_by_week_gas_unlimited,  :thermostatic, :thermostatic_non_heating, :frost_2, :hotwater ] )

# reports.do_all_schools(true)

# reports.do_one_page(:electricity_detail)

# reports.do_chart_list('Boiler Control', [ :baseload,  :electricity_by_month_year_0_1, :intraday_line_school_days] )

# reports.do_chart_list('Boiler Control', [ :thermostatic_control_medium_diurnal_range ] )

# reports.do_one_page(:boiler_control)

# reports.do_all_schools(true)

reports.do_all_standard_pages_for_school

# reports.do_chart_list('Boiler Control', [ :gas_heating_season_intraday ] )

reports.save_excel_and_html

reports.report_benchmarks
