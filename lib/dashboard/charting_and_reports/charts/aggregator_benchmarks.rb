require_relative '../../../../app/services/usage/annual_usage_benchmarks_service.rb'

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
        fuel = fuel_type_str == Series::MultipleFuels::STORAGEHEATERS ? :storage_heaters : fuel_type_str.to_sym
        set_benchmark_buckets(
          results.bucketed_data[fuel_type_str],
          benchmark_data(asof_date, fuel, :exemplar_school,  datatype),
          benchmark_data(asof_date, fuel, :benchmark_school, datatype),
        )
      end
    end

    if benchmark_required?(Series::MultipleFuels::SOLARPV)
      set_benchmark_buckets(results.bucketed_data[Series::MultipleFuels::SOLARPV], 0.0, 0.0, 0.0)
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
    service = Usage::AnnualUsageBenchmarksService.new(school, fuel_type, asof_date)
    benchmarked_usage = service.annual_usage(compare: benchmark_type)
    benchmarked_usage.send(datatype.to_sym)
  end
end
