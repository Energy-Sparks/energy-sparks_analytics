require_relative './advice_general.rb'
class AdviceElectricityCosts < AdviceElectricityBase
  attr_reader :rating
  def rating
    @rating ||= 100.0 * MeterTariffs.accounting_tariff_availability_coverage(aggregate_meter.amr_data.start_date, aggregate_meter.amr_data.end_date, @school.electricity_meters)
  end
end
class AdviceGasCosts < AdviceGasBase
  attr_reader :rating
  def rating
    @rating ||= 100.0 * MeterTariffs.accounting_tariff_availability_coverage(aggregate_meter.amr_data.start_date, aggregate_meter.amr_data.end_date, @school.heat_meters)
  end
end
