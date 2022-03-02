require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

asof_date = Date.new(2022, 2, 27)
schools = ['marksb*']

overrides = {
  schools:  schools,
  alerts:   {
    alerts:  [ AlertSeasonalHeatingSchoolDaysStorageHeaters ], # [ AlertTurnHeatingOff, AlertHeatingOnSchoolDays ],
    control: {
      asof_date: asof_date,
      no_outputs: %i[raw_variables_for_saving],
    }, 
  }
}


script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run

