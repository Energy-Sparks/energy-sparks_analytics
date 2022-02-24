require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

overrides = {
  schools:  ['uptodate*'],
  alerts:   {
    alerts: [ AlertTurnHeatingOff ],
    control: {
      asof_date: Date.new(2022, 2, 21),
      outputs: %i[raw_variables_for_saving],
    }
  }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
