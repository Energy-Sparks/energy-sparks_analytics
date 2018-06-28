# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

puts "========================================================================================"
puts  "electrical simulation"

suppress_school_loading_output = true

reports = DashboardReports.new

school_name = 'Paulton Junior School'

school = reports.load_school(school_name, suppress_school_loading_output)

simulator = ElectricitySimulator.new(school)

simulator.simulate(simulator.default_simulator_parameters)

reports.do_one_page(:simulator)

reports.save_excel_and_html

reports.report_benchmarks
