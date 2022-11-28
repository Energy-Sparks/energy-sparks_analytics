require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new(File.join('log', "alert #{DateTime.now.strftime('%Y-%m-%d %H%M%S')}.log"))
  logger.level = :debug
end

asof_date = Date.new(2022, 11, 5)
schools = ['king-james*']

overrides = {
  schools:  schools,
  cache_school: false,
  alerts:   { alerts: nil, control: { asof_date: asof_date} },
  alerts:   { alerts: [
    # AlertChangeInDailyElectricityShortTerm,
    # AlertChangeInDailyGasShortTerm,
    # AlertElectricityPeakKWVersusBenchmark,
    # AlertSolarPVBenefitEstimator,
    # AlertIntraweekBaseloadVariation,
    # AlertSeasonalBaseloadVariation,
    # AlertGasAnnualVersusBenchmark,
    # AlertOutOfHoursElectricityUsage,
    # AlertOutOfHoursGasUsage,
    # AlertStorageHeaterOutOfHours,
    # AlertWeekendGasConsumptionShortTerm,
    # AlertHeatingComingOnTooEarly
    # AlertHeatingSensitivityAdvice,
    # AlertHeatingOnNonSchoolDays,
    # AlertThermostaticControl,
    # AlertWeekendGasConsumptionShortTerm,
    # AlertTurnHeatingOff,
    # AlertSchoolWeekComparisonGas
    # AlertEnergyAnnualVersusBenchmark
    # AlertSchoolWeekComparisonGas
    # AlertElectricityAnnualVersusBenchmark,
    # AlertGasAnnualVersusBenchmark,
    # AlertStorageHeaterAnnualVersusBenchmark,
    # AlertThermostaticControl,
    # AlertStorageHeaterThermostatic,
    # AlertChangeInDailyGasShortTerm
    # AlertSolarPVBenefitEstimator
    # AlertPreviousHolidayComparisonElectricity
    # AlertSolarPVBenefitEstimator,
    AlertElectricityPeakKWVersusBenchmark
    ], control: { asof_date: asof_date, no_outputs: %i[raw_variables_for_saving], log: [:invalid_alerts] } },
  no_alerts:   { alerts: [ AlertCommunityPreviousHolidayComparisonElectricity ], control: { asof_date: asof_date } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
