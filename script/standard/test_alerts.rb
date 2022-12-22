require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new(File.join('log', "alert #{DateTime.now.strftime('%Y-%m-%d %H%M%S')}.log"))
  logger.level = :debug
end

asof_date = Date.new(2022, 12, 10)
schools = ['wybour*'] # ['king-james*', 'wybour*', 'penny*']

overrides = {
  schools:  schools,
  cache_school: false,
  alerts:   { alerts: nil, control: { asof_date: asof_date} },
  alerts:   { alerts: [
    # AlertEnergyAnnualVersusBenchmark
    # AlertSchoolWeekComparisonGas
    # AlertOutOfHoursElectricityUsage
    # AlertElectricityBaseloadVersusBenchmark
    # AlertHeatingComingOnTooEarly
    # AlertPreviousYearHolidayComparisonElectricity
    # AlertSolarPVBenefitEstimator
    # AlertElectricityAnnualVersusBenchmark
    # AlertGasAnnualVersusBenchmark
    # AlertEnergyAnnualVersusBenchmark
    # AlertElectricityPeakKWVersusBenchmark,
    AlertElectricityAnnualVersusBenchmark,
    AlertGasAnnualVersusBenchmark
    ],
  control: { asof_date: asof_date, outputs: %i[raw_variables_for_saving html_template_variables], log: [:invalid_alerts] } },
  no_alerts:   { alerts: [ AlertCommunityPreviousHolidayComparisonElectricity ], control: { asof_date: asof_date } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
