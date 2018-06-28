# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

puts "========================================================================================"
puts  "electrical simulation"


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

=begin
suppress_output {
   reports = DashboardReports.new
   reports.do_one_school('Paulton Junior School', :simulator)
}
=end

reports = DashboardReports.new

school_name = 'Paulton Junior School'

school = reports.load_school(school_name)

# simulator = ElectricitySimulator.new(school)

# simulator.simulate(simulator.default_simulator_parameters)

reports.do_one_school(school_name, :boiler_control)

