require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/benchmark db %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['.*'], # ['White.*', 'Trin.*', 'Round.*' ,'St John.*'],
  source:                   :analytics_db, # :aggregated_meter_collection, 
  logger2:                  { name: "./log/benchmark %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  
  run_benchmark_charts_and_tables: {
    filename:       './TestResults/benchmark database',
    calculate_and_save_variables: true,
    asof_dates:      [Date.new(2018,9,12), Date.new(2019,9,11)],
    run_charts_and_tables: Date.new(2019,9,11)
  }
}

RunTests.new(script).run
