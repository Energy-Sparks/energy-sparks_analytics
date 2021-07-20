require_relative './alert_storage_heater_mixin.rb'
require_relative './../gas/boiler control/alert_thermostatic_control.rb'
require_relative './../gas/boiler control/alert_school_heating_days.rb'
require_relative './../gas/boiler control/alert_heating_day_base.rb'
require_relative './../common/alert_targets.rb'

class AlertStorageHeaterAnnualVersusBenchmark < AlertGasAnnualVersusBenchmark
  include AlertGasToStorageHeaterSubstitutionMixIn
  def initialize(school)
    super(school, :storage_heater_annual_benchmark)
    @relevance = @school.storage_heaters? ? :relevant : :never_relevant 
  end

  private def dd_adj(asof_date)
    BenchmarkMetrics.normalise_degree_days(@school.temperatures, @school.holidays, :electricity, asof_date)
  end
end

class AlertStorageHeaterThermostatic < AlertThermostaticControl
  include AlertGasToStorageHeaterSubstitutionMixIn
  def initialize(school)
    super(school, :storage_heater_thermostatic)
    @relevance = @school.storage_heaters? ? :relevant : :never_relevant
  end

  def thermostatic_chart
    :storage_heater_thermostatic
  end
end

class AlertStorageHeaterOutOfHours < AlertOutOfHoursGasUsage
  include AlertGasToStorageHeaterSubstitutionMixIn
  def initialize(school)
    super(school, 'electricity', BenchmarkMetrics::PERCENT_STORAGE_HEATER_OUT_OF_HOURS_BENCHMARK,
          BenchmarkMetrics::ELECTRICITY_PRICE, :storageheateroutofhours,
          '', :allstorageheater, 0.2, 0.5)
    @relevance = @school.storage_heaters? ? :relevant : :never_relevant 
  end

  def breakdown_chart
    :alert_daytype_breakdown_storage_heater
  end

  def group_by_week_day_type_chart
    :alert_group_by_week_storage_heaters
  end
end

class AlertHeatingOnSchoolDaysStorageHeaters < AlertHeatingOnSchoolDays
  include AlertGasToStorageHeaterSubstitutionMixIn
  def initialize(school)
    super(school, :storage_heater_heating_days)
    @relevance = @school.storage_heaters? ? :relevant : :never_relevant 
  end

  def heating_on_off_chart
    :heating_on_by_week_with_breakdown_storage_heaters
  end
end

class AlertStorageHeatersLongTermTrend < AlertLongTermTrend
  def initialize(school)
    super(school, :storage_heater_heating_days)
    @relevance = @school.storage_heaters? ? :relevant : :never_relevant 
  end

  def self.template_variables
    specific = { 'Storage heaters long term trend' => long_term_variables('storage heater')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :storage_heaters
  end

  protected def aggregate_meter
    @school.storage_heater_meter
  end
end

class AlertStorageHeaterTargetAnnual < AlertGasTargetAnnual
  def self.template_variables
    specific = { 'Storage heaters targetting and tracking' => long_term_variables('storage heaters')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :storage_heaters
  end

  def aggregate_meter
    @school.storage_heater_meter
  end

  def aggregate_target_meter
    @target_school.storage_heater_meter
  end
end

class AlertStorageHeaterTarget4Week < AlertStorageHeaterTargetAnnual
  def rating_target_percent
    last_4_weeks_percent_of_target
  end
end

class AlertStorageHeaterTarget1Week < AlertStorageHeaterTargetAnnual
  def rating_target_percent
    last_week_percent_of_target
  end
end
