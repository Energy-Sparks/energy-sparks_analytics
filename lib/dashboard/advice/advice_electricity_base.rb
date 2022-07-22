class AdviceElectricityBase < AdviceBase
  protected def aggregate_meter
    @school.aggregated_electricity_meters
  end
  def relevance
    @school.aggregated_electricity_meters.nil? ? :never_relevant : :relevant
  end
end
