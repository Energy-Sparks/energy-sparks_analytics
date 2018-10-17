# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

school_name = 'St Marks Secondary'

module Logging
  @logger = Logger.new('log/test-simulator ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug # :debug
end
ENV['AWESOMEPRINT'] = 'off'

puts "========================================================================================"
puts  "electrical simulation"

suppress_school_loading_output = false

reports = ReportConfigSupport.new

school = reports.load_school(school_name, suppress_school_loading_output)

simulator = ElectricitySimulator.new(school)

bm = Benchmark.measure {
  simulator.simulate(simulator.default_simulator_parameters)
}
puts "Simulator took: #{bm.to_s}"

# reports.do_one_page(:simulator)
reports.do_one_page(:simulator)
reports.do_one_page(:simulator_detail, false)

reports.save_excel_and_html

reports.report_benchmarks

definitions = ElectricitySimulatorConfiguration::APPLIANCE_DEFINITIONS
