# adds benchmarking data as extra x axis onto benchmark charts
class AggregatorBenchmarks < AggregatorBase
  SCALESPLITCHAR = ':'
  def self.exemplar_school_name
    'Exemplar School'
  end

  def self.benchmark_school_name
    'Benchmark (Good) School'
  end

  def inject_benchmarks
    inject_benchmarks_private
  end

  private

  def inject_benchmarks_private
    # reverse X axis on benchmarks only following PM/CT request 18Jan2020
    results.reverse_x_axis

    logger.info "Injecting national, regional and exemplar benchmark data: for #{results.bucketed_data.keys}"

    results.x_axis.push(AggregatorBenchmarks.exemplar_school_name)
    results.x_axis.push(AggregatorBenchmarks.benchmark_school_name)

    most_recent_date_range = results.x_axis_bucket_date_ranges.sort{ |dr1, dr2| dr1.first <=> dr2.first }.last
    asof_date = most_recent_date_range.last
    datatype = @chart_config[:yaxis_units]

    ['electricity', 'gas', Series::MultipleFuels::STORAGEHEATERS].each do |fuel_type_str|
      if benchmark_required?(fuel_type_str)
        set_benchmark_buckets(
          results.bucketed_data[fuel_type_str],
          benchmark_data(asof_date, fuel_type_str.to_sym, :exemplar,  datatype),
          benchmark_data(asof_date, fuel_type_str.to_sym, :benchmark, datatype),
        )
      end
    end

    # TODO (PH, 15Dec2022) - this code mix of pv and sh looks wrong? INvestigate?
    if benchmark_required?(Series::MultipleFuels::SOLARPV)
      set_benchmark_buckets(results.bucketed_data[Series::MultipleFuels::STORAGEHEATERS], 0.0, 0.0, 0.0)
    end
  end

  def benchmark_required?(fuel_type)
    results.bucketed_data.key?(fuel_type) && results.bucketed_data[fuel_type].is_a?(Array) && results.bucketed_data[fuel_type].sum > 0.0
  end

  def set_benchmark_buckets(bucket, exemplar, regional)
    bucket.push(exemplar)
    bucket.push(regional)
  end

  def benchmark_data(asof_date, fuel_type, benchmark_type, datatype)
    @alerts ||= {}
    @alerts[fuel_type] ||= AlertAnalysisBase.benchmark_alert(@school, fuel_type, asof_date)
    @alerts[fuel_type].benchmark_chart_data[benchmark_type][datatype]
  end
end 

=begin
    if benchmark_required?('electricity')
      set_benchmark_buckets(
        results.bucketed_data['electricity'],
        benchmark_data(asof_date, :electricity, :exemplar,  datatype),
        benchmark_data(asof_date, :electricity, :benchmark, datatype),
      )
    end

    if benchmark_required?('gas')
      set_benchmark_buckets(
        results.bucketed_data['gas'],
        benchmark_data(asof_date, :gas, :exemplar,  datatype),
        benchmark_data(asof_date, :gas, :benchmark, datatype),
      )
    end

    if benchmark_required?(Series::MultipleFuels::STORAGEHEATERS)
      set_benchmark_buckets(
        results.bucketed_data[Series::MultipleFuels::STORAGEHEATERS],
        benchmark_data(asof_date, :storage_heater, :exemplar,  datatype),
        benchmark_data(asof_date, :storage_heater, :benchmark, datatype),
      )
    end
    # Centrica: need to support 2x series 1 for community use, 1 without

    most_recent_start_date = most_recent_date_range.first
    most_recent_end_date   = most_recent_date_range.last
    @current_year_floor_area = school.floor_area(most_recent_start_date, most_recent_end_date)
    @current_year_number_of_pupils = school.number_of_pupils(most_recent_start_date, most_recent_end_date)

    
    # scale_school_data if chart_config.scale_y_axis?

  def scale_benchmarks_deprecated(benchmark_usage_kwh, fuel_type)
    benchmark_usage_kwh / blended_rate_£_per_kwh(fuel_type, @chart_config[:yaxis_units])
  end

  def scale_school_data_deprecated
    chart_config.scale_y_axis.each do |scale|
      case scale.keys.first
      when :number_of_pupils
        scale_by_pupils(scale.values.first)
      when :floor_area
        scale_by_floor_area(scale.values.first)
      else
        raise EnergySparksUnexpectedStateException, "Chart configuration scale_y_axis setting #{scale.keys.first}"
      end
    end
  end

  def scale_by_pupils_deprecated(scale_config)
    raise EnergySparksUnexpectedStateException, "Chart configuration scale_by_pupils setting #{scale_config}" if scale_config[:to] != :to_current_period

    return unless results[:bucketed_data].include?(scale_config[:series_name])

    pupils = results[:x_axis_bucket_date_ranges].map do |(start_date, end_date)|
      @school.number_of_pupils(start_date, end_date)
    end

    pupils_scale = pupils.map { |num_pupils| num_pupils / pupils.last }

    results[:bucketed_data][scale_config[:series_name]].each.with_index do |_v, i|
      results[:bucketed_data][scale_config[:series_name]][i] *= pupils_scale[i]
    end

    results[:x_axis].each.with_index do |x_axis_label, i|
      if i < pupils.length
        if pupils_scale[i] != 1.0
          results[:x_axis][i] += "#{SCALESPLITCHAR} #{scale_config[:series_name]} scaled from #{pupils[i].round(0)} to #{pupils.last.round(0)} pupils"
        else
          results[:x_axis][i] += "#{SCALESPLITCHAR} #{pupils.last.round(0)} pupils (not scaled)"
        end
      else
        results[:x_axis][i] += "#{SCALESPLITCHAR} #{scale_config[:series_name]} (#{pupils.last.round(0)} pupils)"
      end
    end
  end

  def scale_by_floor_area_deprecated(scale_config)
    raise EnergySparksUnexpectedStateException, "Chart configuration scale_by_floor_area setting #{scale_config}" if scale_config[:to] != :to_current_period

    return unless results[:bucketed_data].include?(scale_config[:series_name])

    floor_areas = results[:x_axis_bucket_date_ranges].map do |(start_date, end_date)|
      @school.floor_area(start_date, end_date)
    end

    floor_area_scale = floor_areas.map { |fa| fa / floor_areas.last }

    results[:bucketed_data][scale_config[:series_name]].each.with_index do |_v, i|
      results[:bucketed_data][scale_config[:series_name]][i] *= floor_area_scale[i]
    end

    results[:x_axis].each.with_index do |x_axis_label, i|
      if i < floor_areas.length
        if floor_area_scale[i] != 1.0
          results[:x_axis][i] += "#{SCALESPLITCHAR} #{scale_config[:series_name]} floor area scaled from #{floor_areas[i].round(0)}m2 to #{floor_areas.last.round(0)}m2"
        else
          results[:x_axis][i] += "#{SCALESPLITCHAR} #{floor_areas.last.round(0)} floor_areas (not scaled)"
        end
      else
        results[:x_axis][i] += "#{SCALESPLITCHAR} #{scale_config[:series_name]} (floor area #{floor_areas.last.round(0)}m2)"
      end
    end
  end

  def exemplar_electricity_usage_in_units_deprecated(asof_date)
    benchmark_data(asof_date, :electricity, :exemplar, @chart_config[:yaxis_units])
  end

  def blended_rate_£_per_kwh_deprecated(fuel_type, unit)
    return 1.0 if unit == :kwh

    if fuel_type == :storage_heaters && meter_collection.aggregate_meter(:gas).nil?
      BenchmarkMetrics::GAS_PRICE
    else
      fuel_type = :gas if fuel_type == :storage_heaters # compare storage heater £ with gas £ to encourage fuel switch
      @school.aggregate_meter(fuel_type).amr_data.blended_rate(unit, :kwh, last_start_date, last_end_date)
    end
  end

  def last_end_date_deprecated
    results[:x_axis_bucket_date_ranges].flatten.sort.last
  end

  def last_start_date_deprecated
    results[:x_axis_bucket_date_ranges].flatten.sort.last(2).first
  end

  def benchmark_heating_usage_deprecated(target_benchmark_per_m2, fuel_type, dd_ajust)
    dd_adjustment = dd_ajust ?  (1.0 / BenchmarkMetrics.normalise_degree_days(@school.temperatures, @school.holidays, fuel_type, last_end_date)) : 1.0
    scale_benchmarks(target_benchmark_per_m2 * @current_year_floor_area, fuel_type) * dd_adjustment
  end

  def national_benchmark_gas_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2, :gas, false)
  end

  def national_benchmark_storage_heater_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2, :storage_heaters, false)
  end

  def national_exemplar_gas_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2, :storage_heaters, false)
  end

  def national_exemplar_storage_heater_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2, :storage_heaters, false)
  end

  def regional_benchmark_gas_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2, :gas, true)
  end

  def regional_benchmark_storage_heater_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2, :storage_heaters, true)
  end

  def regional_exemplar_gas_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2, :gas, true)
  end

  def regional_exemplar_storage_heater_usage_in_units_deprecated
    benchmark_heating_usage(BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2, :storage_heaters, true)
  end
end

=end
