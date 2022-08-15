require_relative './meter_breakdown_advice.rb'
require_relative './advice_boiler_heating_base.rb'
require_relative './advice_electricity_base.rb'

class AdviceElectricityMeterBreakdownBase < AdviceMeterBreakdownBase
  protected def aggregate_meter; @school.aggregated_electricity_meters end
  protected def underlying_meters; @school.electricity_meters end
end
class AdviceGasMeterBreakdownBase < AdviceMeterBreakdownBase
  protected def aggregate_meter; @school.aggregated_heat_meters end
  protected def underlying_meters; @school.heat_meters end
end
class AdviceGasOutHours < AdviceGasBase;    end
class AdviceElectricityOutHours < AdviceElectricityBase; end
class AdviceElectricityLongTerm < AdviceElectricityBase; end

class AdviceGasLongTerm < AdviceGasBase; end

class AdviceGasIntraday < AdviceGasBase
  def rating
    5.0
  end
end

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

class AdviceEnergyTariffs < AdviceElectricityBase; end
