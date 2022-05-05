require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

asof_date = Date.new(2022, 4, 22)
schools = ['penyrheol-warm*']

overrides = {
  schools:  schools,
  alerts:   { alerts: [ AlertTurnHeatingOff ], control: { asof_date: asof_date, outputs: %i[raw_variables_for_saving], log: [:invalid_alerts] } }
  # alerts:   { alerts: [ AlertElectricityTarget1Week, AlertGasTarget1Week ], control: { asof_date: Date.new(2022, 2, 1) } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
