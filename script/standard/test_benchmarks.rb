require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

module Logging
  @logger = Logger.new(File.join('log', 'benchmarks.log'))
  logger.level = :error
end

run_date = Date.new(2022, 8, 14)

overrides = { 
  schools: ['bish*'], # ['shrew*', 'bathamp*'],
  cache_school: true,
  benchmarks: {
    calculate_and_save_variables: true,
    asof_date: run_date,
    pages: %i[
      annual_heating_costs_per_floor_area
      change_in_annual_heating_consumption
      change_in_gas_consumption_recent_school_weeks
      change_in_gas_holiday_consumption_previous_holiday
      change_in_gas_holiday_consumption_previous_years_holiday
    ],
    run_content: { asof_date: run_date } # , filter: ->{ !gpyc_difp.nil? && !gpyc_difp.infinite?.nil? } }
  }
}

puts "Got here script"

script = RunBenchmarks.default_config.deep_merge(overrides)

RunTests.new(script).run
