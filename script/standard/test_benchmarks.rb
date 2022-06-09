require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

module Logging
  @logger = Logger.new(File.join('log', 'benchmarks.log'))
  logger.level = :error
end


run_date = Date.new(2022, 5, 22)

overrides = { 
  schools: ['king*'],
  cache_school: false,
  benchmarks: {
    calculate_and_save_variables: true,
    asof_date:     run_date,
    run_content: { asof_date: run_date }
  }
}

script = RunBenchmarks.default_config.deep_merge(overrides)

RunTests.new(script).run
