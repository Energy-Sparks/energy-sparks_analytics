class AdviceGasOutHours < AdviceBase
  protected def aggregate_meter
    @school.aggregated_heat_meters
  end
end