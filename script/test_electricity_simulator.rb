# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

puts "========================================================================================"
puts  "electrical simulation"

=begin
# old code

fromeSchool = School.new("Trinity School", "Frome BA11", 1100, 300)

simulator = ElectricitySimulator.new(mostRecentAcademicYear, holidays, temperatures, solarinsolence, fromeSchool)

simulator.simulate(applianceDefinitions)

excel.addData("Boiler Pumps", 					simulator.calcComponentsResults["Boiler Pumps"])
excel.addData("Security Lighting", 				simulator.calcComponentsResults["Security Lighting"])
excel.addData("Kitchen", 						simulator.calcComponentsResults["Kitchen"])
excel.addData("Air Conditioning", 				simulator.calcComponentsResults["Air Conditioning"])
excel.addData("Unaccounted For Baseload", 		simulator.calcComponentsResults["Unaccounted For Baseload"])

# puts simulator.calcComponentsResults

=end

def suppress_output
  begin
    original_stdout = $stdout.clone
    $stdout.reopen(File.new('./Results/suppressed_log.txt', 'w'))
    retval = yield
  rescue StandardError => e
    $stdout.reopen(original_stdout)
    raise e
  ensure
    $stdout.reopen(original_stdout)
  end
  retval
end

# example testing choices:
#
#   1. do_all_schools
#
#   2. do_one_school('Bishop Sutton Primary School')
#
#   3. do_one_school('Bishop Sutton Primary School', :main_dashboard_electric_and_gas)
#
#   4. do_one_school('Bishop Sutton Primary School', :main_dashboard_electric_and_gas, :benchmark)
#

reports = nil

suppress_output {
  reports = DashboardReports.new
  reports.do_one_school('Paulton Junior School', :simulator)
}

school = reports.load_school('Paulton Junior School')

simulator = ElectricitySimulator.new(school)

simulator.simulate(simulator.default_simulator_parameters)
