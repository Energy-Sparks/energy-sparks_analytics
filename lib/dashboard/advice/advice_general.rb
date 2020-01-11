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
class AdviceElectricityCosts < AdviceElectricityBase; end
class AdviceGasCosts < AdviceGasBase; end
class AdviceGasOutHours < AdviceGasBase;    end
class AdviceGasAnnual   < AdviceGasBase;    end
class AdviceBenchmark   < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters # TODO(PH, 21Oct2019) - needs to check gas asof as well
  end
end
class AdviceElectricityOutHours < AdviceElectricityBase; end
class AdviceElectricityLongTerm < AdviceElectricityBase; end
class AdviceElectricityIntraday < AdviceElectricityBase
  def rating
    5.0
  end
end

class AdviceGasLongTerm < AdviceGasBase; end
class AdviceGasIntraday < AdviceGasBase
  def rating
    5.0
  end
end

class AdviceGasBoilerMorningStart < AdviceGasBase
  def relevance
    super &&  !non_heating_only? ? :relevant : :never_relevant
  end
end
class AdviceGasBoilerSeasonalControl < AdviceGasBase
  def relevance
    super &&  !non_heating_only? ? :relevant : :never_relevant
  end
end
class AdviceGasBoilerThermostatic < AdviceGasBase
  def relevance
    super &&  !non_heating_only? ? :relevant : :never_relevant
  end
end
class AdviceGasBoilerFrost < AdviceGasBase
  def rating
    5.0
  end
  def relevance
    super &&  !non_heating_only? ? :relevant : :never_relevant
  end
end
class AdviceGasHotWater < AdviceGasBase
  def relevance
    super &&  !heating_only? ? :relevant : :never_relevant
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

class AdviceCarbon < AdviceElectricityBase
  def relevance
    @school.gas? && @school.electricity? ? :relevant : :never_relevant
  end

  def rating
    5.0
  end
end
class AdviceEnergyTariffs < AdviceElectricityBase; end
