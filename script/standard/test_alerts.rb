require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

asof_date = Date.new(2022, 4, 10)
schools = ['a*']

overrides = {
  schools:  schools,
  control: { cache_school: false },
  alerts:   { alerts: nil, control: { asof_date: asof_date }  },
  # alerts:   { alerts: [ AlertHotWaterEfficiency ], control: { asof_date: asof_date } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
