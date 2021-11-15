require_relative './synthetic_school.rb'

class BenchmarkSchool < SyntheticSchool
  def initialize(school, benchmark_type: :benchmark)
    super(school)
    @name = benchmark_type.to_s
    calculate_benchmark_meters(benchmark_type)
  end

  private

  def calculate_benchmark_meters(benchmark_type)
    benchmark_electricity_meter = create_benchmark_meter(:electricity, benchmark_type)
    set_aggregate_meter(:electricity, benchmark_electricity_meter)
  end

  def create_benchmark_meter(fuel_type, benchmark_type)
    original_meter = @original_school.aggregate_meter(fuel_type)
    benchmark_meter = SyntheticMeter.new(original_meter)

    calculator = AverageSchoolCalculator.new(@original_school)
    benchmark_meter.amr_data = calculator.benchmark_amr_data(type: benchmark_type)

    benchmark_meter.set_carbon_and_costs
    set_aggregate_meter(fuel_type, benchmark_meter)
  end
end
