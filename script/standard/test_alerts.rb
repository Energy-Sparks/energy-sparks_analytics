require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new(File.join('log', 'logs.log'))
  logger.level = :error
end

asof_date = Date.new(2022, 5, 22)
schools = ['*']

overrides = {
  schools:  schools,
  alerts:   { alerts: nil, control: { asof_date: asof_date} },
  # alerts:   { alerts: [ AlertTurnHeatingOff ], control: { asof_date: asof_date, outputs: %i[raw_variables_for_saving], log: [:invalid_alerts] } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
