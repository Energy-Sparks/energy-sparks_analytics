require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
puts "Got here tttttttttttttttttttt"
overrides = {
  schools:  ['king-ja*'],
  alerts:   { alerts: [ AlertHeatingOnOff ], control: { asof_date: Date.new(2022, 1, 10) } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
