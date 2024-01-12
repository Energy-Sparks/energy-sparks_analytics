require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

# module Logging
#   @logger = Logger.new(File.join('log', "alert #{DateTime.now.strftime('%Y-%m-%d %H%M%S')}.log"))
#   logger.level = :debug
# end

asof_date = Date.new(2023, 10, 2)
# schools = ['t*']
schools = ['ki*']

overrides = {
  schools:  schools,
  cache_school: false,
  alerts:   { alerts: nil, control: { asof_date: asof_date} },
  alerts:   { alerts: [
#    AlertElectricityBaseloadVersusBenchmark
#    AlertThermostaticControl
#    AlertEnergyAnnualVersusBenchmark,
#    AlertSchoolWeekComparisonGas,
#    AlertOutOfHoursElectricityUsage,
#    AlertElectricityBaseloadVersusBenchmark,
#    AlertHeatingComingOnTooEarly,
#    AlertPreviousYearHolidayComparisonElectricity,
#    AlertSolarPVBenefitEstimator,
#    AlertElectricityAnnualVersusBenchmark,
#    AlertElectricityLongTermTrend,
#    AlertGasAnnualVersusBenchmark,
#    AlertEnergyAnnualVersusBenchmark,
#    AlertElectricityPeakKWVersusBenchmark,
#    AlertElectricityBaseloadVersusBenchmark,
#    AlertSeasonalBaseloadVariation,
#    AlertIntraweekBaseloadVariation,
#    AlertGasAnnualVersusBenchmark,
#    AlertGasLongTermTrend,
#    AlertChangeInElectricityBaseloadShortTerm,
#    AlertPreviousYearHolidayComparisonElectricity,
#    AlertPreviousHolidayComparisonElectricity,
#    AlertLayerUpPowerdown11November2022ElectricityComparison,
#    AlertEaster2023ShutdownElectricityComparison,
#    AlertEaster2023ShutdownGasComparison,
#    AlertEaster2023ShutdownStorageHeaterComparison
#    AlertOutOfHoursElectricityUsagePreviousYear
#     AlertSolarGeneration
#    AlertJanAug20222023ElectricityComparison,
#    AlertJanAug20222023GasComparison,
#    AlertJanAug20222023StorageHeaterComparison,
    AlertEnergyAnnualVersusBenchmark,
    AlertAdditionalPrioritisationData
    ],
  control: { asof_date: asof_date, outputs: %i[raw_variables_for_saving html_template_variables], log: [:invalid_alerts] } },
  no_alerts:   { alerts: [], control: { asof_date: asof_date } }
}

script = RunAlerts.default_config.deep_merge(overrides)

RunTests.new(script).run
