require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

overrides = {
  schools:  ['uptodate*'],
  alerts:   {
    alerts: [ AlertHeatingOn, AlertHeatingOff ],
    control: {
      asof_date: Date.new(2022, 2, 20),
    }
  }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
