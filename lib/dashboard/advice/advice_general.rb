require_relative './meter_breakdown_advice.rb'
class AdviceGasBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_heat_meters
  end
  def relevance
    @school.aggregated_heat_meters.nil? ? :never_relevant : :relevant
  end
  def non_heating_only?
    aggregate_meter.non_heating_only?
  end
  def heating_only?
    aggregate_meter.heating_only?
  end
end
class AdviceElectricityBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
  def relevance
    @school.aggregated_electricity_meters.nil? ? :never_relevant : :relevant
  end
end
class AdviceElectricityMeterBreakdownBase < AdviceMeterBreakdownBase
  protected def aggregate_meter; @school.aggregated_electricity_meters end
  protected def underlying_meters; @school.electricity_meters end
end
class AdviceGasMeterBreakdownBase < AdviceMeterBreakdownBase
  protected def aggregate_meter; @school.aggregated_heat_meters end
  protected def underlying_meters; @school.heat_meters end
end
class AdviceGasOutHours < AdviceGasBase;    end
class AdviceGasAnnual   < AdviceGasBase;    end
class AdviceBenchmark   < AdviceBase
  def alert_asof_date
    valid_meters.map { |meter| meter.amr_data.end_date }.min
  end
  protected def aggregate_meter
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.first
  end
  def valid_alert?
    super && valid_meters.all?{ |m| m.amr_data.days > 364 }
  end
  private
  def valid_meters
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact
  end
end
class AdviceElectricityOutHours < AdviceElectricityBase; end
class AdviceElectricityLongTerm < AdviceElectricityBase; end

class AdviceGasLongTerm < AdviceGasBase; end
class AdviceGasIntraday < AdviceGasBase
  def rating
    5.0
  end
end

class AdviceBoilerHeatingBase < AdviceGasBase
  def relevance
    super == :relevant &&  !non_heating_only? ? :relevant : :never_relevant
  end
end

class AdviceGasBoilerSeasonalControl  < AdviceBoilerHeatingBase; end
class AdviceGasBoilerThermostatic     < AdviceBoilerHeatingBase; end

class AdviceGasBoilerFrost < AdviceBoilerHeatingBase
  def rating
    5.0
  end
end

class AdviceGasHotWater < AdviceGasBase
  def relevance
    super == :relevant &&  !heating_only? ? :relevant : :never_relevant
  end
end

class AdviceStorageHeaters < AdviceElectricityBase
  def relevance
    @school.storage_heaters? ? :relevant : :never_relevant
  end
  def rating
    5.0
  end
end

class AdviceEnergyTariffs < AdviceElectricityBase; end
