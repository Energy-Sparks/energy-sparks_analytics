require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

FUEL_TYPES = %i[electricity gas] # %i[electricity gas  storage_heater]

def example_manually_configured_scenarios
  [
    { fuel_types: %i[electricity gas], target: 0.95 },
    { target_start_date:   -7, truncate_amr_data: 365 * 2,  move_end_date: -90,  fuel_types: FUEL_TYPES, target: 0.95 },
    { target_start_date:   -7, truncate_amr_data: 365 * 2,  move_end_date: -90,  fuel_types: FUEL_TYPES, target: 0.95 },
    { target_start_date:   -7, truncate_amr_data: 365 * 1,  move_end_date:   0,  fuel_types: FUEL_TYPES, target: 0.90 },
    { target_start_date:   -7, truncate_amr_data: 365 * 1,  move_end_date: -180, fuel_types: FUEL_TYPES, target: 0.90 },
    { target_start_date: -180, truncate_amr_data: 720,      move_end_date:   0,  fuel_types: FUEL_TYPES, target: 0.90 },
  ]
end

def example_manually_configured_scenarios2
  [
    { target_start_date:   -7, truncate_amr_data: 365 -  0 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  1 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  2 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  3 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  4 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  5 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  6 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  7 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  8 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 -  9 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 - 10 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
    { target_start_date:   -7, truncate_amr_data: 365 - 11 * 30,  move_end_date: 0,  fuel_types: FUEL_TYPES, target: 1.0 },
  ]
end

def script(scenarios)
  control = RunTargetingAndTracking.default_control_settings.deep_merge({ control: {scenarios: scenarios}})

  {
    logger1:                { name: TestDirectory.instance.log_directory + "/TnT estimate variance %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },

    schools:                ['king-james*'],

    source:                 :unvalidated_meter_data,

    logger2:                { name: TestDirectory.instance.log_directory + "/TnT estimate variance %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },

    targeting_and_tracking: control
  }
end

RunTests.new(script(example_manually_configured_scenarios2)).run
