require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

def scenarios
  [
    { target_start_date:  -7, truncate_amr_data: 265 * 2, fuel: %i[electricity gas] },
    { target_start_date:  -7, truncate_amr_data: 265 * 1, fuel: %i[electricity gas] },
  ]
end

def script(scenarios)
  control = RunTargetingAndTracking.default_control_settings.deep_merge({ control: {scenarios: scenarios}})
  {
    logger1:                { name: TestDirectoryConfiguration::LOG + "/test targeting and tracking %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },

    schools: ['trini*'],
    source:                 :unvalidated_meter_data,

    logger2:                { name: TestDirectoryConfiguration::LOG + "/targeting and tracking %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },

    targeting_and_tracking: control
  }
end

RunTests.new(script(scenarios)).run
