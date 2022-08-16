require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

module Logging
  @logger = Logger.new(File.join('log', 'benchmarks.log'))
  logger.level = :error
end

run_date = Date.new(2022, 8, 5)

overrides = { 
  schools: ['*'], # ['shrew*', 'bathamp*'],
  cache_school: false,
  benchmarks: {
    calculate_and_save_variables: true,
    asof_date: run_date,
    no_pages: [:change_in_gas_holiday_consumption_previous_holiday, :change_in_gas_holiday_consumption_previous_years_holiday],
    run_content: { asof_date: run_date }
  }
}

script = RunBenchmarks.default_config.deep_merge(overrides)

RunTests.new(script).run
