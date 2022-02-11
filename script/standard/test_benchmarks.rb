require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

run_date = Date.new(2022, 1, 20)

overrides = { 
  schools: ['bath*'],
  benchmarks: {
    calculate_and_save_variables: true,
    asof_date:     run_date,
    run_content: { asof_date: run_date }
  }
}

script = RunBenchmarks.default_config.deep_merge(overrides)

RunTests.new(script).run
