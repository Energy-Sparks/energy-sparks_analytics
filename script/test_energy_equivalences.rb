# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-equivalances ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/equivalences %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  schools:                  ['.*'], # ['Round.*'],
  source:                   :analytics_db,
  logger2:                  { name: "./log/equivalences %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  equivalences:          {
                              control: {
                                periods: [
                                  {academicyear: 0},
                                  {workweek: 0},
                                  {schoolweek: 0},
                                  {schoolweek: -1},
                                  {month: 0},
                                  {month: -1}
                                ],
                                compare_results: [
                                  { comparison_directory: '../TestResults/Equivalences/Base' },
                                  { output_directory:     '../TestResults/Equivalences/New' },
                                ]
                              }
                            }
}

RunTests.new(script).run
