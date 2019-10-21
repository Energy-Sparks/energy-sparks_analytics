class AdviceGasBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_heat_meters
  end
end
class AdviceElectricityBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
end
class AdviceGasOutHours < AdviceGasBase;    end
class AdviceGasAnnual   < AdviceGasBase;    end
class AdviceBenchmark   < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters # TODO(PH, 21Oct2019) - needs to check gas asof as well
  end
end
class AdviceElectricityAnnual < AdviceElectricityBase; end
class AdviceElectricityOutHours < AdviceElectricityBase; end
class AdviceElectricityLongTerm < AdviceElectricityBase; end
class AdviceElectricityRecent < AdviceElectricityBase; end
class AdviceElectricityIntraday < AdviceElectricityBase; end

class AdviceGasLongTerm < AdviceGasBase; end
class AdviceGasRecent < AdviceGasBase; end
class AdviceGasIntraday < AdviceGasBase; end

class AdviceGasBoilerMorningStart < AdviceGasBase; end
class AdviceGasBoilerSeasonalControl < AdviceGasBase; end
class AdviceGasBoilerThermostatic < AdviceGasBase; end
class AdviceGasBoilerFrost < AdviceGasBase; end
class AdviceGasHotWater < AdviceGasBase; end

class AdviceStorageHeaters < AdviceElectricityBase; end
class AdviceSolarPV < AdviceElectricityBase; end

class AdviceCarbon < AdviceElectricityBase; end
class AdviceEnergyTariffs < AdviceElectricityBase; end
