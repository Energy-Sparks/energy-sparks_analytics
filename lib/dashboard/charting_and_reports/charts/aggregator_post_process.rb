class AggregatorPostProcess < AggregatorBase
  def initialize(multi_school_periods)
    super(multi_school_periods.school, multi_school_periods.chart_config, multi_school_periods.results)
  end

  def calculate
    inject_benchmarks if chart_config.inject_benchmark?
  end

  private

  def inject_benchmarks
    bm = AggregatorBenchmarks.new(school, chart_config, results)
    bm.inject_benchmarks
  end
end
