class AdviceElectricityBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
  def relevance
    aggregate_meter.nil? ? :never_relevant : :relevant
  end
end
