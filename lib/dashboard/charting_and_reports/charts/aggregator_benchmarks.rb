# adds benchmarking data as extra x axis onto benchmark charts
class AggregatorBenchmarks < AggregatorBase
  def inject_benchmarks
    inject_benchmarks_private
  end

  private

  def inject_benchmarks_private

    # reverse X axis on benchmarks only following PM/CT request 18Jan2020
    results.reverse_x_axis

    logger.info "Injecting national, regional and exemplar benchmark data: for #{results.bucketed_data.keys}"

    results.x_axis.push('Exemplar School')
    results.x_axis.push('Regional Average')
    results.x_axis.push('National Average')

    if benchmark_required?('electricity')
      set_benchmark_buckets(
        results.bucketed_data['electricity'],
        exemplar_electricity_usage_in_units,
        benchmark_electricity_usage_in_units, # there is no difference between national and regional for electricity'
        benchmark_electricity_usage_in_units
      )
    end

    if benchmark_required?('gas')
      set_benchmark_buckets(
        results.bucketed_data['gas'],
        regional_exemplar_gas_usage_in_units,
        regional_benchmark_gas_usage_in_units,
        national_benchmark_gas_usage_in_units
      )
    end

    if benchmark_required?(Series::MultipleFuels::STORAGEHEATERS)
      set_benchmark_buckets(
        results.bucketed_data[Series::MultipleFuels::STORAGEHEATERS],
        regional_exemplar_storage_heater_usage_in_units,
        regional_benchmark_storage_heater_usage_in_units,
        national_benchmark_storage_heater_usage_in_units
      )
    end

    # Centrica: need to support 2x series 1 for community use, 1 without

    if benchmark_required?(Series::MultipleFuels::SOLARPV)
      set_benchmark_buckets(results.bucketed_data[Series::MultipleFuels::STORAGEHEATERS], 0.0, 0.0, 0.0)
    end
  end

  def benchmark_required?(fuel_type)
    results.bucketed_data.key?(fuel_type) && results.bucketed_data[fuel_type].is_a?(Array) && results.bucketed_data[fuel_type].sum > 0.0
  end

  def set_benchmark_buckets(bucket, exemplar, regional, national)
    bucket.push(exemplar)
    bucket.push(regional)
    bucket.push(national)
  end

  def scale_benchmarks(benchmark_usage_kwh, fuel_type)
    # price storage heater fuel the same as gas, as the benchmark is either
    # gas heating or ASHP/AirCon with better COP, and therefore lower effective £/delivered kWh
    fuel_type = :gas if fuel_type == :storage_heaters
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(benchmark_usage_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], fuel_type, @school)
  end

  def exemplar_electricity_usage_in_units
    exemplar_annual_kwh = BenchmarkMetrics.exemplar_annual_electricity_usage_kwh(@school.school_type, @school.number_of_pupils)
    # slight issue here is that this chart is typically in £, and if the school
    # has a differential tariff then the £ and kWh comparisons versus exemplar will be different
    scale_benchmarks(exemplar_annual_kwh, :electricity)
  end

  def benchmark_electricity_usage_in_units
    benchmark_annual_kwh = BenchmarkMetrics.benchmark_annual_electricity_usage_kwh(@school.school_type, @school.number_of_pupils)
    # slight issue here is that this chart is typically in £, and if the school
    # has a differential tariff then the £ and kWh comparisons versus benchmark will be different
    scale_benchmarks(benchmark_annual_kwh, :electricity)
  end

  def benchmark_heating_usage(target_benchmark_per_m2, fuel_type, dd_ajust)
    dd_adjustment = dd_ajust ?  (1.0 / BenchmarkMetrics.normalise_degree_days(@school.temperatures, @school.holidays, fuel_type)) : 1.0
    scale_benchmarks(target_benchmark_per_m2 * @school.floor_area, fuel_type) * dd_adjustment
  end

  def benchmark_gas_usage_kwh_per_m2
    BenchmarkMetrics.benchmark_gas_usage_kwh_per_m2(@school)
  end

  def exemplar_gas_usage_kwh_per_m2
    BenchmarkMetrics.exemplar_gas_usage_kwh_per_m2(@school)
  end

  def national_benchmark_gas_usage_in_units
    benchmark_heating_usage(benchmark_gas_usage_kwh_per_m2, :gas, false)
  end

  def national_benchmark_storage_heater_usage_in_units
    benchmark_heating_usage(benchmark_gas_usage_kwh_per_m2, :storage_heaters, false)
  end

  def national_exemplar_gas_usage_in_units
    benchmark_heating_usage(exemplar_gas_usage_kwh_per_m2, :storage_heaters, false)
  end

  def national_exemplar_storage_heater_usage_in_units
    benchmark_heating_usage(exemplar_gas_usage_kwh_per_m2, :storage_heaters, false)
  end

  def regional_benchmark_gas_usage_in_units
    benchmark_heating_usage(benchmark_gas_usage_kwh_per_m2, :gas, true)
  end

  def regional_benchmark_storage_heater_usage_in_units
    benchmark_heating_usage(benchmark_gas_usage_kwh_per_m2, :storage_heaters, true)
  end

  def regional_exemplar_gas_usage_in_units
    benchmark_heating_usage(exemplar_gas_usage_kwh_per_m2, :gas, true)
  end

  def regional_exemplar_storage_heater_usage_in_units
    benchmark_heating_usage(exemplar_gas_usage_kwh_per_m2, :storage_heaters, true)
  end
end
