require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

overrides = {
  schools:  ['bath*'],
  alerts:   { alerts: nil, control: { asof_date: Date.new(2022, 1, 22) } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
