class AdviceGasBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_heat_meters
  end
  def relevance
    @school.aggregated_heat_meters.nil? ? :never_relevant : :relevant
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
class AdviceGasOutHours < AdviceGasBase;    end
class AdviceGasAnnual   < AdviceGasBase;    end
class AdviceBenchmark   < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters # TODO(PH, 21Oct2019) - needs to check gas asof as well
  end
end
class AdviceElectricityOutHours < AdviceElectricityBase; end
class AdviceElectricityLongTerm < AdviceElectricityBase; end
class AdviceElectricityRecent < AdviceElectricityBase; end
class AdviceElectricityIntraday < AdviceElectricityBase
  def rating
    5.0
  end
end

class AdviceGasLongTerm < AdviceGasBase; end
class AdviceGasRecent < AdviceGasBase; end
class AdviceGasIntraday < AdviceGasBase
  def rating
    5.0
  end
end

class AdviceGasBoilerMorningStart < AdviceGasBase; end
class AdviceGasBoilerSeasonalControl < AdviceGasBase; end
class AdviceGasBoilerThermostatic < AdviceGasBase; end
class AdviceGasBoilerFrost < AdviceGasBase
  def rating
    5.0
  end
end
class AdviceGasHotWater < AdviceGasBase; end

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
