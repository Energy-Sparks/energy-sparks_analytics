require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

module Logging
  @logger = Logger.new(File.join('log', 'benchmarks.log'))
  logger.level = :error
end

run_date = Date.new(2022, 11, 5)

overrides = { 
  schools: ['king-james-e*', 'wyb*', 'batheas*'], # ['shrew*', 'bathamp*'],
  cache_school: false,
  benchmarks: {
    calculate_and_save_variables: true,
    asof_date: run_date,
    pages: %i[
      recent_change_in_baseload
      baseload_per_pupil
      seasonal_baseload_variation
      weekday_baseload_variation
    ],
    run_content: { asof_date: run_date } # , filter: ->{ !gpyc_difp.nil? && !gpyc_difp.infinite?.nil? } }
  }
}

puts "Got here script"

script = RunBenchmarks.default_config.deep_merge(overrides)

RunTests.new(script).run
