class AdviceStorageHeaters < AdviceElectricityBase
  def relevance
    @school.storage_heaters? ? :relevant : :never_relevant
  end

  def rating
    5.0
  end

  def aggregate_meter
    @school.storage_heater_meter
  end

  def normalised_benchmark_chart_name
    :benchmark_storage_heater_only_£_varying_floor_area_pupils
  end
end
