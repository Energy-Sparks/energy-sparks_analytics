class AdviceGasAnnual < AdviceBenchmark
  def aggregate_meter
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

  def normalised_benchmark_chart_name
    :benchmark_gas_only_£_varying_floor_area_pupils
  end

  private

  def valid_meters
    [@school.aggregated_heat_meters]
  end  
end
