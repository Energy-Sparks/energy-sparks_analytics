require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

overrides = {
  schools:  ['*'],
  alerts:   { alerts: nil, control: { asof_date: Date.new(2022, 2, 1) } }
  # alerts:   { alerts: [ AlertElectricityTarget1Week, AlertGasTarget1Week ], control: { asof_date: Date.new(2022, 2, 1) } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
