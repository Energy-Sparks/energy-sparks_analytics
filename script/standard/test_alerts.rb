require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log\logs.log')
  logger.level = :error
end

asof_date = Date.new(2022, 4, 23)
schools = ['marksb*']

overrides = {
  schools:  ['king-j*'],
  alerts:   { alerts: nil, control: { asof_date: asof_date} }
  # alerts:   { alerts: [ AlertElectricityTarget1Week, AlertGasTarget1Week ], control: { asof_date: Date.new(2022, 2, 1) } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
