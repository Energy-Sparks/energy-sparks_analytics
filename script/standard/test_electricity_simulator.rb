# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

@@energysparksanalyticsautotest = {
  original_data: '../TestResults/Charts/Base/',
  new_data:      '../TestResults/Charts/New/'
}

school_name = 'St Marks Secondary'

module Logging
  @logger = Logger.new('log/test-simulator ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug # :debug
end

reports = ReportConfigSupport.new

def test_one_school(school_name, reports)
  return if school_name != 'Roundhill School'
  puts '=' * 120
  puts "Running electricity simulator for #{school_name}"
  puts
  suppress_school_loading_output = false

  school = reports.load_school(school_name, suppress_school_loading_output)

  if school.gas_only?
    puts "Can't run simulator for this school #{school_name} as only has gas meters"
    return
  end

  simulator = ElectricitySimulator.new(school)

  bm = Benchmark.measure {
    simulator.simulate(simulator.default_simulator_parameters)
  }
  puts "Simulator took: #{bm.to_s}"

  reports.do_one_page(:simulator)
  reports.do_one_page(:simulator_detail, false)

  reports.excel_name = school_name + ' - simulator'

  reports.save_excel_and_html

  reports.report_benchmarks

  definitions = ElectricitySimulatorConfiguration::APPLIANCE_DEFINITIONS
  Logging.logger.warn "HERE: #{definitions[:unaccounted_for_baseload]}"
end

puts "========================================================================================"
puts  "electrical simulation"

list_of_schools = reports.schools.keys

list_of_schools.each do |school_name|
  test_one_school(school_name, reports)
end
