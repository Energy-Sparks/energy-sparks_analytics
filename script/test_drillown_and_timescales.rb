require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['White.*'], # ['Round.*'],
  source:                   :analytics_db,
  logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  # drilldown:                true
  timescales:               true
}

RunTests.new(script).run
